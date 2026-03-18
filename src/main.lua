--
-- ConstructionSearch
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

local modDirectory = g_currentModDirectory

-- search constants
local SEARCH_CATEGORY_NAME = "search"
local FUZZY_THRESHOLD = 0.6
local SEARCH_DEBOUNCE_MS = 150
local SEARCH_MIN_LENGTH = 2

-- sort mode definitions with compare functions
local SORT_MODES = {
  sort_relevance = {
    l10nKey = "constructionSearch_sort_relevance",
    compare = function(a, b)
      local scoreA = a.fuzzyScore or 0
      local scoreB = b.fuzzyScore or 0

      if scoreA == scoreB then
        return (a.searchOrder or 0) < (b.searchOrder or 0)
      end

      return scoreA > scoreB
    end
  },
  sort_price_asc = {
    l10nKey = "constructionSearch_sort_price_asc",
    toggleTo = "sort_price_desc",
    chipId = "sort_price",
    compare = function(a, b)
      local priceA = a.item and a.item.price or 0
      local priceB = b.item and b.item.price or 0

      if priceA == priceB then
        return (a.searchOrder or 0) < (b.searchOrder or 0)
      end

      return priceA < priceB
    end
  },
  sort_price_desc = {
    l10nKey = "constructionSearch_sort_price_desc",
    toggleTo = "sort_price_asc",
    chipId = "sort_price",
    compare = function(a, b)
      local priceA = a.item and a.item.price or 0
      local priceB = b.item and b.item.price or 0

      if priceA == priceB then
        return (a.searchOrder or 0) < (b.searchOrder or 0)
      end

      return priceA > priceB
    end
  },
  sort_name_asc = {
    l10nKey = "constructionSearch_sort_name_asc",
    toggleTo = "sort_name_desc",
    chipId = "sort_name",
    compare = function(a, b)
      local nameA = a.item and a.item.name or ""
      local nameB = b.item and b.item.name or ""

      if nameA == nameB then
        return (a.searchOrder or 0) < (b.searchOrder or 0)
      end

      return nameA < nameB
    end
  },
  sort_name_desc = {
    l10nKey = "constructionSearch_sort_name_desc",
    toggleTo = "sort_name_asc",
    chipId = "sort_name",
    compare = function(a, b)
      local nameA = a.item and a.item.name or ""
      local nameB = b.item and b.item.name or ""

      if nameA == nameB then
        return (a.searchOrder or 0) < (b.searchOrder or 0)
      end

      return nameA > nameB
    end
  }
}

-- mapping from chip ID to default sort mode
local CHIP_TO_MODE = {
  sort_relevance = "sort_relevance",
  sort_price = "sort_price_asc",
  sort_name = "sort_name_asc"
}

-- diacritics to ASCII normalization map (for accent-insensitive search)
local DIACRITICS_TO_ASCII = {
  -- polish
  ["ą"] = "a", ["ć"] = "c", ["ę"] = "e", ["ł"] = "l", ["ń"] = "n",
  ["ó"] = "o", ["ś"] = "s", ["ź"] = "z", ["ż"] = "z",
  -- german
  ["ä"] = "a", ["ö"] = "o", ["ü"] = "u", ["ß"] = "ss",
  -- french
  ["à"] = "a", ["â"] = "a", ["ç"] = "c", ["è"] = "e", ["é"] = "e",
  ["ê"] = "e", ["ë"] = "e", ["î"] = "i", ["ï"] = "i", ["ô"] = "o",
  ["ù"] = "u", ["û"] = "u", ["ÿ"] = "y",
  -- spanish/portuguese
  ["ñ"] = "n", ["á"] = "a", ["ã"] = "a", ["í"] = "i", ["ì"] = "i",
  ["ò"] = "o", ["õ"] = "o", ["ú"] = "u",
  -- czech/slovak
  ["č"] = "c", ["ď"] = "d", ["ě"] = "e", ["ň"] = "n", ["ř"] = "r",
  ["š"] = "s", ["ť"] = "t", ["ů"] = "u", ["ž"] = "z", ["ý"] = "y",
  ["ľ"] = "l", ["ĺ"] = "l", ["ŕ"] = "r",
  -- hungarian
  ["ő"] = "o", ["ű"] = "u",
  -- romanian
  ["ă"] = "a", ["â"] = "a", ["î"] = "i", ["ș"] = "s", ["ț"] = "t",
  -- scandinavian
  ["å"] = "a", ["æ"] = "ae", ["ø"] = "o",
  -- turkish
  ["ğ"] = "g", ["ı"] = "i", ["ş"] = "s",
  -- vietnamese
  ["ả"] = "a", ["ạ"] = "a", ["ắ"] = "a", ["ằ"] = "a", ["ẳ"] = "a",
  ["ẵ"] = "a", ["ặ"] = "a", ["ấ"] = "a", ["ầ"] = "a", ["ẩ"] = "a",
  ["ẫ"] = "a", ["ậ"] = "a", ["đ"] = "d", ["ẻ"] = "e", ["ẽ"] = "e",
  ["ẹ"] = "e", ["ế"] = "e", ["ề"] = "e", ["ể"] = "e", ["ễ"] = "e",
  ["ệ"] = "e", ["ỉ"] = "i", ["ĩ"] = "i", ["ị"] = "i", ["ỏ"] = "o",
  ["ọ"] = "o", ["ố"] = "o", ["ồ"] = "o", ["ổ"] = "o", ["ỗ"] = "o",
  ["ộ"] = "o", ["ơ"] = "o", ["ớ"] = "o", ["ờ"] = "o", ["ở"] = "o",
  ["ỡ"] = "o", ["ợ"] = "o", ["ủ"] = "u", ["ũ"] = "u", ["ụ"] = "u",
  ["ư"] = "u", ["ứ"] = "u", ["ừ"] = "u", ["ử"] = "u", ["ữ"] = "u",
  ["ự"] = "u", ["ỳ"] = "y", ["ỷ"] = "y", ["ỹ"] = "y", ["ỵ"] = "y",
  -- russian (cyrillic to latin transliteration)
  ["а"] = "a", ["б"] = "b", ["в"] = "v", ["г"] = "g", ["д"] = "d",
  ["е"] = "e", ["ё"] = "e", ["ж"] = "zh", ["з"] = "z", ["и"] = "i",
  ["й"] = "y", ["к"] = "k", ["л"] = "l", ["м"] = "m", ["н"] = "n",
  ["о"] = "o", ["п"] = "p", ["р"] = "r", ["с"] = "s", ["т"] = "t",
  ["у"] = "u", ["ф"] = "f", ["х"] = "kh", ["ц"] = "ts", ["ч"] = "ch",
  ["ш"] = "sh", ["щ"] = "shch", ["ъ"] = "", ["ы"] = "y", ["ь"] = "",
  ["э"] = "e", ["ю"] = "yu", ["я"] = "ya",
  -- ukrainian (additional)
  ["і"] = "i", ["ї"] = "yi", ["є"] = "ye", ["ґ"] = "g"
}

---Normalizes text for search comparison
-- @param text string the text to normalize
-- @return string the normalized text
local function normalizeText(text)
  if text == nil or text == "" then
    return ""
  end

  local lowerText = utf8ToLower(text)

  local result = lowerText:gsub("[\194-\244][\128-\191]+", function(char)
    return DIACRITICS_TO_ASCII[char] or char
  end)

  return result
end

---Extracts readable English name from XML filename
-- @param item table the construction item
-- @return string the English name extracted from filename
local function getEnglishNameFromItem(item)
  local xmlFilename = nil

  if item.displayItem ~= nil and item.displayItem.storeItem ~= nil then
    xmlFilename = item.displayItem.storeItem.xmlFilename
  end

  if xmlFilename == nil and item.xmlFilename ~= nil then
    xmlFilename = item.xmlFilename
  end

  if xmlFilename == nil or xmlFilename == "" then
    return ""
  end

  local filename = xmlFilename:match("([^/\\]+)%.xml$") or xmlFilename:match("([^/\\]+)$") or ""

  if filename == "" then
    return ""
  end

  local result = filename:gsub("_", " ")
  result = result:gsub("(%l)(%u)", "%1 %2")
  result = result:lower()

  return result
end

---Builds a stable identifier for construction items
-- @param item table the construction item
-- @return string|nil the unique identifier
local function getItemIdentifier(item)
  if item == nil then
    return nil
  end

  if item.storeItem ~= nil and item.storeItem.xmlFilename ~= nil then
    return string.lower(tostring(item.storeItem.xmlFilename))
  end

  if item.brushParameters ~= nil and #item.brushParameters > 0 then
    local brushType = "brush"

    if item.brushClass == ConstructionBrushSculpt then
      brushType = "sculpt"
    elseif item.brushClass == ConstructionBrushPaint then
      brushType = "paint"
    elseif item.brushClass ~= nil then
      brushType = tostring(item.brushClass)
    end

    local parameters = {}

    for i = 1, #item.brushParameters do
      parameters[i] = tostring(item.brushParameters[i])
    end

    return string.format("%s:%s", brushType, table.concat(parameters, "|"))
  end

  if item.name ~= nil then
    return string.lower(tostring(item.name))
  end

  return nil
end

---Updates the search icon based on whether text is empty
-- @param self table the ConstructionScreen instance
-- @param isEmpty boolean whether the search text is empty
local function getSearchState(self)
  if self.constructionSearch == nil then
    self.constructionSearch = {}
  end

  return self.constructionSearch
end

---Updates the search icon based on whether text is empty
-- @param self table the ConstructionScreen instance
-- @param isEmpty boolean whether the search text is empty
local function updateSearchIcon(self, isEmpty)
  local search = getSearchState(self)

  if search.iconButton == nil then
    return
  end

  local iconId = isEmpty and "gui.icon_pen" or "gui.cross"
  search.iconButton:setImageSlice(nil, iconId)
end

---Gets current text from search input element
-- @param self table the ConstructionScreen instance
-- @return string currentText
local function getSearchInputText(self)
  local search = getSearchState(self)

  if search.inputElement == nil then
    return ""
  end

  local currentText = search.inputElement.text

  if type(currentText) ~= "string" and search.inputElement.getText ~= nil then
    currentText = search.inputElement:getText() or ""
  end

  return type(currentText) == "string" and currentText or ""
end

---Updates placeholder text visibility inside search input
-- @param self table the ConstructionScreen instance
-- @param isEmpty boolean whether the search text is empty
-- @param isEditing boolean|nil current editing state override
local function updateSearchInputPlaceholder(self, isEmpty, isEditing)
  local search = getSearchState(self)

  if search.placeholderElement == nil then
    return
  end

  if isEditing == nil then
    isEditing = search.inputElement ~= nil and search.inputElement.forcePressed
  end

  search.placeholderElement:setVisible(isEmpty and not isEditing)
end

---Updates search input visual state
-- @param self table the ConstructionScreen instance
-- @param isEmpty boolean whether the search text is empty
local function updateSearchInputState(self, isEmpty)
  updateSearchIcon(self, isEmpty)
  updateSearchInputPlaceholder(self, isEmpty)
end

---Clears pending debounced search request
-- @param self table the ConstructionScreen instance
local function clearPendingSearch(self)
  local search = getSearchState(self)

  search.pendingText = nil
  search.pendingTime = nil
end

---Focuses the search input if it exists
-- @param self table the ConstructionScreen instance
-- @return table|nil input element
local function focusSearchInput(self)
  local inputElement = getSearchState(self).inputElement

  if inputElement ~= nil then
    FocusManager:setFocus(inputElement)
  end

  return inputElement
end

local updateSortChips

---Builds cached normalized fields for search matching
-- @param item table the construction item
-- @param category table|nil the current category
-- @param tab table|nil the current tab
-- @return table normalized search fields
local function createSearchFields(item, category, tab)
  local categoryName = category and category.name or ""
  local categoryTitle = category and category.title or ""
  local tabName = tab and tab.name or ""
  local tabTitle = tab and tab.title or ""
  local brandName = ""
  local brandTitle = ""
  local modName = ""

  if item.displayItem ~= nil and item.displayItem.storeItem ~= nil then
    local storeItem = item.displayItem.storeItem
    local brandIndex = storeItem.brandIndex

    if brandIndex ~= nil then
      local brand = g_brandManager:getBrandByIndex(brandIndex)

      if brand ~= nil then
        brandName = brand.name or ""
        brandTitle = brand.title or ""
      end
    end

    modName = storeItem.dlcTitle or ""
  end

  return {
    normalizeText(type(item.name) == "string" and item.name or tostring(item.name or "")),
    normalizeText(categoryName),
    normalizeText(categoryTitle),
    normalizeText(tabName),
    normalizeText(tabTitle),
    normalizeText(brandName),
    normalizeText(brandTitle),
    normalizeText(getEnglishNameFromItem(item)),
    normalizeText(modName)
  }
end

---Applies search results to the search category items array
-- @param self table the ConstructionScreen instance
local function applySearchResultsToSearchCategory(self)
  local search = getSearchState(self)
  local searchCategoryIndex = search.categoryIndex

  if searchCategoryIndex == nil then
    return
  end

  local searchCategory = self.categories ~= nil and self.categories[searchCategoryIndex] or nil

  if searchCategory == nil or searchCategory.name ~= SEARCH_CATEGORY_NAME then
    return
  end

  local items = self.items[searchCategoryIndex] or {}
  items[1] = {}

  local results = search.results or {}
  for i = 1, #results do
    items[1][i] = results[i].item
  end

  self.items[searchCategoryIndex] = items
end

---Creates search placeholder overlay
-- @param self table the ConstructionScreen instance
local function createSearchPlaceholder(self)
  local search = getSearchState(self)

  if search.placeholder ~= nil then
    return
  end

  local sliceInfo = g_overlayManager:getSliceInfoById("gui.storeAttribute_consoleSlots")

  if sliceInfo == nil then
    return
  end

  local overlay = Overlay.new(sliceInfo.filename, 0, 0, 0.02, 0.02 * g_screenAspectRatio)
  overlay:setUVs(sliceInfo.uvs)
  overlay:setColor(1, 1, 1, 0.3)

  search.placeholder = overlay
  search.placeholderVisible = false
end

---Updates search placeholder visibility
-- @param self table the ConstructionScreen instance
-- @param visible boolean whether to show the placeholder
local function updateSearchPlaceholder(self, visible)
  local search = getSearchState(self)

  if search.placeholder == nil and visible then
    createSearchPlaceholder(self)
  end

  search.placeholderVisible = visible
end

---Shows placeholder text in details panel for search mode
-- @param self table the ConstructionScreen instance
local function showSearchPlaceholderDetails(self)
  self:assignItemAttributeData(nil)

  if self.itemDetailsName ~= nil then
    self.itemDetailsName:setText(g_i18n:getText("constructionSearch_search"))
    self.itemDetailsName:setVisible(true)
  end
end

---Shows empty search state in list/details panel
-- @param self table the ConstructionScreen instance
-- @param isInputEmpty boolean whether the input is empty
local function showEmptySearchState(self, isInputEmpty)
  updateSearchInputState(self, isInputEmpty)
  updateSearchPlaceholder(self, true)
  showSearchPlaceholderDetails(self)
end

---Refreshes list/details UI after search results changed
-- @param self table the ConstructionScreen instance
-- @param isEmpty boolean whether the search text is empty
local function refreshSearchResultsView(self, isEmpty)
  local search = getSearchState(self)

  applySearchResultsToSearchCategory(self)
  self.itemList:reloadData()

  local hasResults = #(search.results or {}) > 0

  updateSearchInputState(self, isEmpty)
  updateSearchPlaceholder(self, isEmpty or not hasResults)

  if hasResults then
    self.itemList:setSelectedIndex(1)
    self:assignItemAttributeData(search.results[1].item)
  else
    showSearchPlaceholderDetails(self)
  end
end

---Calculates fuzzy match score between query and text
-- Returns score 0.0 to 1.0 where 1.0 is perfect match
-- @param query string the search query (lowercase)
-- @param text string the text to search in (lowercase)
-- @return number the match score
local function fuzzyScore(query, text)
  if query == "" then
    return 0
  end

  if string.find(text, query, 1, true) then
    if string.sub(text, 1, #query) == query then
      return 1.0
    end

    local matchPos = string.find(text, query, 1, true)
    if matchPos == 1 or string.sub(text, matchPos - 1, matchPos - 1) == " " then
      return 0.95
    end

    return 0.85
  end

  local queryLen = #query
  local textLen = #text

  if queryLen > textLen then
    return 0
  end

  if queryLen <= 2 then
    return 0
  end

  local queryIndex = 1
  local matchedChars = 0
  local consecutiveCount = 0
  local maxConsecutive = 0
  local lastMatchIndex = 0
  local totalGap = 0
  local wordStartBonus = 0

  for i = 1, textLen do
    if queryIndex > queryLen then
      break
    end

    local queryChar = string.sub(query, queryIndex, queryIndex)
    local textChar = string.sub(text, i, i)

    if queryChar == textChar then
      matchedChars = matchedChars + 1

      if lastMatchIndex > 0 then
        local gap = i - lastMatchIndex - 1
        totalGap = totalGap + gap

        if gap > 5 then
          return 0
        end

        if gap == 0 then
          consecutiveCount = consecutiveCount + 1
          maxConsecutive = math.max(maxConsecutive, consecutiveCount)
        else
          consecutiveCount = 0
        end
      end

      if i == 1 or string.sub(text, i - 1, i - 1) == " " then
        wordStartBonus = wordStartBonus + 0.1
      end

      lastMatchIndex = i
      queryIndex = queryIndex + 1
    end
  end

  if matchedChars < queryLen then
    return 0
  end

  if queryLen >= 4 then
    local consecutiveRatio = (maxConsecutive + 1) / queryLen
    if consecutiveRatio < 0.5 then
      return 0
    end
  end

  local avgGap = totalGap / math.max(1, matchedChars - 1)
  if avgGap > 3 then
    return 0
  end

  local matchSpan = lastMatchIndex - (lastMatchIndex - totalGap - matchedChars + 1) + 1
  local density = matchedChars / math.max(matchSpan, queryLen)

  local consecutiveBonus = (maxConsecutive / queryLen) * 0.2
  local gapPenalty = avgGap * 0.05
  local finalScore = math.min(0.8, density * 0.6 + consecutiveBonus + wordStartBonus - gapPenalty)

  return math.max(0, finalScore)
end

---Performs search across all construction items
-- Supports multi-word fuzzy search (all words must match)
-- Results are sorted by match quality (best first)
-- @param self table the ConstructionScreen instance
-- @param text string the search query
local function performSearch(self, text)
  local search = getSearchState(self)
  search.results = {}

  if text == nil or text == "" then
    return
  end

  -- Check minimum length requirement
  if #text < SEARCH_MIN_LENGTH then
    return
  end

  local searchNormalized = normalizeText(text)

  local searchWords = {}
  for word in string.gmatch(searchNormalized, "%S+") do
    table.insert(searchWords, word)
  end

  if #searchWords == 0 then
    return
  end

  for i = 1, #(search.allItems or {}) do
    local searchItem = search.allItems[i]
    local fields = searchItem.searchFields or {}

    local allWordsMatch = true
    local totalScore = 0

    for _, word in ipairs(searchWords) do
      local bestScore = 0

      for _, field in ipairs(fields) do
        local score = fuzzyScore(word, field)

        if score > bestScore then
          bestScore = score
        end
      end

      if bestScore < FUZZY_THRESHOLD then
        allWordsMatch = false
        break
      end

      totalScore = totalScore + bestScore
    end

    if allWordsMatch then
      searchItem.fuzzyScore = totalScore / #searchWords
      table.insert(search.results, searchItem)
    end
  end

  local sortMode = SORT_MODES[search.sortMode or "sort_relevance"]
  if sortMode and sortMode.compare then
    table.sort(search.results, sortMode.compare)
  end
end

---Executes the actual search and updates UI
-- @param self table the ConstructionScreen instance
-- @param text string the search text
local function executeSearch(self, text)
  getSearchState(self).text = text
  performSearch(self, text)
  refreshSearchResultsView(self, text == "")
end

---Called when search text changes (with debounce)
-- @param self table the ConstructionScreen instance
-- @param text string the new search text
local function onSearchTextChanged(self, text)
  local search = getSearchState(self)
  text = type(text) == "string" and text or ""

  local upperText = utf8ToUpper(text)
  if upperText ~= text and search.inputElement ~= nil then
    search.inputElement:setText(upperText)
    text = upperText
  end

  local isEmpty = text == ""

  updateSearchInputState(self, isEmpty)

  if isEmpty then
    clearPendingSearch(self)
    executeSearch(self, text)
  else
    search.pendingText = text
    search.pendingTime = g_time + SEARCH_DEBOUNCE_MS
  end
end

---Creates search text input element from XML
-- @param self table the ConstructionScreen instance
-- @return table|nil the created search input element
local function createSearchInput(self)
  local search = getSearchState(self)

  if search.inputCreated then
    return search.inputElement
  end

  local xmlPath = modDirectory .. "data/searchInput.xml"
  local xmlFile = loadXMLFile("constructionSearchInput", xmlPath)

  if xmlFile == nil or xmlFile == 0 then
    Logging.warning("[ConstructionSearch] Failed to load GUI XML: %s", xmlPath)
    return nil
  end

  local parentElement = self.subCategorySelector.parent
  local numElementsBefore = #parentElement.elements

  g_gui:loadProfileSet(xmlFile, "GUI.GUIProfiles", g_gui.presets)
  g_gui:loadGuiRec(xmlFile, "GUI", parentElement, self)
  delete(xmlFile)

  local numElementsAfter = #parentElement.elements

  if numElementsAfter <= numElementsBefore then
    Logging.warning("[ConstructionSearch] No GUI elements loaded from XML")
    return nil
  end

  local containerElement = parentElement.elements[numElementsAfter]
  local inputElement = containerElement:getDescendantById("searchTextInput") or containerElement
  local placeholderElement = containerElement:getDescendantById("searchPlaceholderText")
  local iconButton = containerElement:getDescendantById("searchIconButton")

  local subPos = self.subCategorySelector.position
  local subSize = self.subCategorySelector.size

  containerElement:setPosition(subPos[1], subPos[2])
  containerElement:setSize(subSize[1], subSize[2])
  containerElement:setVisible(false)
  containerElement:updateAbsolutePosition()

  inputElement.target = self

  local originalSetForcePressed = inputElement.setForcePressed
  inputElement.setForcePressed = function(element, force, ...)
    updateSearchInputPlaceholder(self, getSearchInputText(self) == "", force)

    if originalSetForcePressed ~= nil then
      return originalSetForcePressed(element, force, ...)
    end
  end

  local sortChipsContainer = containerElement:getDescendantById("sortChips")

  search.inputContainer = containerElement
  search.inputElement = inputElement
  search.placeholderElement = placeholderElement
  search.iconButton = iconButton
  search.sortChipsContainer = sortChipsContainer
  search.inputCreated = true

  updateSearchInputPlaceholder(self, getSearchInputText(self) == "")
  updateSortChips(self)

  return inputElement
end

---Exits search mode and restores normal category view
-- @param self table the ConstructionScreen instance
local function exitSearchMode(self)
  local search = getSearchState(self)

  if not search.isSearchMode then
    return
  end

  clearPendingSearch(self)
  search.isSearchMode = false
  search.results = {}
  search.text = ""
  self.subCategorySelector:setVisible(true)

  updateSearchPlaceholder(self, false)

  if search.actionEventId ~= nil then
    g_inputBinding:removeActionEvent(search.actionEventId)
    search.actionEventId = nil
  end

  if search.inputContainer ~= nil then
    search.inputContainer:setVisible(false)
  end
end

---Enters search mode and shows search input
-- @param self table the ConstructionScreen instance
-- @param index number the category index
local function enterSearchMode(self, index)
  local search = getSearchState(self)

  search.isSearchMode = true
  self.categorySelector:setSelectedIndex(index)
  self.currentCategory = index
  self.currentTab = 1

  for key, dot in pairs(self.subCategoryDotBox.elements) do
    dot:delete()
    self.subCategoryDotBox.elements[key] = nil
  end

  self.subCategoryDotBox:invalidateLayout()

  if not search.inputCreated then
    createSearchInput(self)
  end

  self.subCategorySelector:setVisible(false)

  if search.inputContainer ~= nil then
    search.inputContainer:setVisible(true)
  end

  if search.inputElement ~= nil then
    local currentText = getSearchInputText(self)

    if currentText ~= "" then
      executeSearch(self, currentText)
    else
      showEmptySearchState(self, true)
    end

    focusSearchInput(self)
  else
    updateSearchPlaceholder(self, true)
    showSearchPlaceholderDetails(self)
  end

  self:removeMenuActionEvents()
  self:registerMenuActionEvents(true)

  self:setBrush(self.selectorBrush, true)
  self:updateMenuState()
end

---Builds flat list of all items from all categories
-- @param self table the ConstructionScreen instance
local function buildAllItemsList(self)
  local search = getSearchState(self)
  search.allItems = {}

  local seen = {}
  local searchCategoryIndex = search.categoryIndex

  for categoryIndex, categoryTabs in ipairs(self.items) do
    if categoryIndex ~= searchCategoryIndex then
      local category = self.categories[categoryIndex]

      for tabIndex, tabItems in ipairs(categoryTabs) do
        local tab = category and category.tabs and category.tabs[tabIndex]

        for i = 1, #tabItems do
          local item = tabItems[i]
          local identifier = getItemIdentifier(item)

          if identifier == nil or not seen[identifier] then
            if identifier ~= nil then
              seen[identifier] = true
            end

            local searchOrder = #search.allItems + 1

            table.insert(search.allItems, {
              item = item,
              searchOrder = searchOrder,
              searchFields = createSearchFields(item, category, tab)
            })
          end
        end
      end
    end
  end
end

---Adds search category to categories list if not exists
-- @param self table the ConstructionScreen instance
local function addSearchCategory(self)
  local search = getSearchState(self)

  for i, category in ipairs(self.categories) do
    if category.name == SEARCH_CATEGORY_NAME then
      search.categoryIndex = i

      if self.items[search.categoryIndex] == nil then
        self.items[search.categoryIndex] = { [1] = {} }
      end

      return
    end
  end

  table.insert(self.categories, {
    name = SEARCH_CATEGORY_NAME,
    title = g_i18n:getText("constructionSearch_search"),
    iconSliceId = "gui.icon_vehicleDealer_search",
    iconFilename = nil,
    iconUVs = nil,
    tabs = { { title = g_i18n:getText("constructionSearch_search") } }
  })

  search.categoryIndex = #self.categories
  self.items[search.categoryIndex] = { [1] = {} }
  self.categorySelector:reloadData()
end

---Override for setCurrentCategory to handle search mode
-- @param self table the ConstructionScreen instance
-- @param superFunc function the original function
-- @param index number the category index
-- @param tabIndex number the tab index
local function setCurrentCategory(self, superFunc, index, tabIndex)
  if index ~= getSearchState(self).categoryIndex then
    exitSearchMode(self)
    return superFunc(self, index, tabIndex)
  end

  enterSearchMode(self, index)
end

---
ConstructionScreen.setCurrentCategory = Utils.overwrittenFunction(ConstructionScreen.setCurrentCategory, setCurrentCategory)

---Override for setCurrentTab to prevent tab changes in search mode
-- @param self table the ConstructionScreen instance
-- @param superFunc function the original function
-- @param index number the tab index
local function setCurrentTab(self, superFunc, index)
  if getSearchState(self).isSearchMode then
    self.currentTab = 1
    focusSearchInput(self)
    return
  end

  return superFunc(self, index)
end

---
ConstructionScreen.setCurrentTab = Utils.overwrittenFunction(ConstructionScreen.setCurrentTab, setCurrentTab)

---Override for onClickItem to handle search results click
-- @param self table the ConstructionScreen instance
-- @param superFunc function the original function
local function onClickItem(self, superFunc)
  local search = getSearchState(self)

  if not search.isSearchMode or search.results == nil then
    return superFunc(self)
  end

  local searchItem = search.results[self.itemList.selectedIndex]

  if searchItem == nil then
    return
  end

  local item = searchItem.item

  if item == nil or item.brushClass == nil then
    return
  end

  local brush = item.brushClass.new(nil, self.cursor)

  if item.brushParameters ~= nil then
    brush:setStoreItem(item.storeItem)
    brush:setParameters(unpack(item.brushParameters))
    brush.uniqueIndex = item.uniqueIndex
  end

  self.destructMode = false
  self:setBrush(brush, true)
end

---
ConstructionScreen.onClickItem = Utils.overwrittenFunction(ConstructionScreen.onClickItem, onClickItem)

---Appended to rebuildData to initialize search state and add category
-- @param self table the ConstructionScreen instance
local function rebuildData(self)
  local search = getSearchState(self)

  search.categoryIndex = nil
  clearPendingSearch(self)
  search.results = {}
  search.text = search.text or ""
  search.isSearchMode = search.isSearchMode or false
  search.sortMode = search.sortMode or "sort_relevance"

  addSearchCategory(self)
  buildAllItemsList(self)

  if search.text ~= "" then
    performSearch(self, search.text)

    if search.isSearchMode and self.currentCategory == search.categoryIndex then
      refreshSearchResultsView(self, false)
    else
      applySearchResultsToSearchCategory(self)
    end
  end
end

---
ConstructionScreen.rebuildData = Utils.appendedFunction(ConstructionScreen.rebuildData, rebuildData)

---Updates sort chip labels and selected state
-- @param self table the ConstructionScreen instance
updateSortChips = function(self)
  local search = getSearchState(self)

  if search.sortChipsContainer == nil then
    return
  end

  local currentSortMode = search.sortMode or "sort_relevance"
  local activeMode = SORT_MODES[currentSortMode]

  for _, chip in pairs(search.sortChipsContainer.elements) do
    if chip.id then
      local modeId = CHIP_TO_MODE[chip.id]

      if activeMode ~= nil and activeMode.chipId == chip.id then
        modeId = currentSortMode
      end

      local mode = modeId ~= nil and SORT_MODES[modeId] or nil

      chip:setSelected(modeId == currentSortMode)

      if mode ~= nil and mode.l10nKey ~= nil then
        chip:setText(g_i18n:getText(mode.l10nKey))
      end
    end
  end
end

---Called when a sort chip is clicked
-- @param element table the clicked chip element
function ConstructionScreen:onSortChipClick(element)
  local search = getSearchState(self)

  if element == nil or element.id == nil then
    return
  end

  local chipId = element.id
  local currentSortMode = search.sortMode or "sort_relevance"
  local currentMode = SORT_MODES[currentSortMode]
  local newModeId

  if currentMode and currentMode.chipId == chipId then
    newModeId = currentMode.toggleTo
  else
    newModeId = CHIP_TO_MODE[chipId]
  end

  if newModeId == nil then
    return
  end

  local newMode = SORT_MODES[newModeId]
  if newMode == nil then
    return
  end

  search.sortMode = newModeId
  updateSortChips(self)

  if search.results and #search.results > 0 then
    table.sort(search.results, newMode.compare)
    refreshSearchResultsView(self, search.text == "")
  end
end

---Called from XML onTextChanged attribute
-- @param _ table the input element
-- @param text string the current text
function ConstructionScreen:onSearchTextChanged(_, text)
  onSearchTextChanged(self, text)
end

---Called when search icon is clicked (clears search if text exists)
function ConstructionScreen:onSearchIconClick()
  local search = getSearchState(self)
  local hasText = search.text ~= nil and search.text ~= ""

  if hasText and search.inputElement ~= nil then
    search.inputElement:setText("")
    onSearchTextChanged(self, "")
  end

  focusSearchInput(self)
end

---Processes pending debounced search
-- @param self table the ConstructionScreen instance
-- @param dt number delta time in milliseconds
local function onUpdate(self, dt)
  local search = getSearchState(self)

  if search.pendingText == nil or search.pendingTime == nil then
    return
  end

  if g_time < search.pendingTime then
    return
  end

  local text = search.pendingText
  clearPendingSearch(self)

  executeSearch(self, text)
end

---
ConstructionScreen.update = Utils.appendedFunction(ConstructionScreen.update, onUpdate)

---Draws the search placeholder overlay
-- @param self table the ConstructionScreen instance
local function onDraw(self)
  local search = getSearchState(self)

  if not search.placeholderVisible then
    return
  end

  if search.placeholder == nil then
    return
  end

  local listContainer = self.itemList.parent

  if listContainer == nil then
    return
  end

  local size = 0.02
  local sizeY = size * g_screenAspectRatio
  local posX = listContainer.absPosition[1] + (listContainer.absSize[1] - size) * 0.5
  local posY = listContainer.absPosition[2] + (listContainer.absSize[2] - sizeY) * 0.5

  search.placeholder:setPosition(posX, posY)
  search.placeholder:render()
end

---
ConstructionScreen.draw = Utils.appendedFunction(ConstructionScreen.draw, onDraw)

---Called when search action event is triggered
-- @param self table the ConstructionScreen instance
function ConstructionScreen:onSearchActionEvent()
  local search = getSearchState(self)

  if search.isSearchMode and self.currentCategory == search.categoryIndex then
    local inputElement = focusSearchInput(self)

    if inputElement ~= nil then
      inputElement.blockTime = 0
      inputElement:onFocusActivate()
    end
  end
end

---Registers search action event
-- @param self table the ConstructionScreen instance
local function onRegisterMenuActionEvents(self)
  local search = getSearchState(self)

  if search.isSearchMode and self.currentCategory == search.categoryIndex then
    local _, eventId = g_inputBinding:registerActionEvent(InputAction.MENU_CANCEL, self, self.onSearchActionEvent, false, true, false, true)
    g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_VERY_LOW)
    g_inputBinding:setActionEventText(eventId, g_i18n:getText("constructionSearch_search"))

    search.actionEventId = eventId
    table.insert(self.menuEvents, eventId)
  end
end

---
ConstructionScreen.registerMenuActionEvents = Utils.appendedFunction(ConstructionScreen.registerMenuActionEvents, onRegisterMenuActionEvents)

---Clears search action event reference on menu cleanup
-- @param self table the ConstructionScreen instance
local function onRemoveMenuActionEvents(self)
  getSearchState(self).actionEventId = nil
end

---
ConstructionScreen.removeMenuActionEvents = Utils.appendedFunction(ConstructionScreen.removeMenuActionEvents, onRemoveMenuActionEvents)

---Cleans up search resources on screen delete
-- @param self table the ConstructionScreen instance
local function onDelete(self)
  local search = getSearchState(self)

  clearPendingSearch(self)
  search.categoryIndex = nil
  if search.inputContainer ~= nil then
    search.inputContainer:delete()
    search.inputContainer = nil
  end

  if search.placeholder ~= nil then
    search.placeholder:delete()
    search.placeholder = nil
  end

  search.inputElement = nil
  search.inputCreated = false
  search.isSearchMode = false
  search.placeholderVisible = false
  search.results = nil
  search.allItems = nil
  search.text = nil
  search.sortMode = nil
  search.placeholderElement = nil
  search.iconButton = nil
  search.sortChipsContainer = nil
  search.actionEventId = nil

  self.constructionSearch = nil
end

---
ConstructionScreen.delete = Utils.prependedFunction(ConstructionScreen.delete, onDelete)
