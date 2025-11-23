/**
 * Calendar Controls Module
 *
 * Provides reusable calendar navigation utilities for Gaming Time and Session History pages.
 * Handles year display, year navigation, and month grid updates with configurable callbacks.
 */

/**
 * Formats a month string as "YYYY-MM"
 * @param {number} year - Full year (e.g., 2025)
 * @param {number} month - Month index (0-11)
 * @returns {string} Formatted month string
 */
function formatMonthString(year, month) {
  return `${year}-${String(month + 1).padStart(2, '0')}`;
}

/**
 * Formats a date string as "YYYY-MM-DD"
 * @param {number} year - Full year (e.g., 2025)
 * @param {number} month - Month index (0-11)
 * @param {number} day - Day of month (1-31)
 * @returns {string} Formatted date string
 */
function formatDateString(year, month, day) {
  return `${year}-${String(month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
}

/**
 * Updates the calendar year display element
 * @param {number} calendarYear - The year to display
 * @param {Object} [config] - Optional configuration
 * @param {Function} [config.yearDisplayCallback] - Callback for custom year display styling
 */
function updateYearDisplay(calendarYear, config = {}) {
  const yearDisplayElement = document.getElementById('year-display');
  yearDisplayElement.textContent = calendarYear;

  // Allow custom callback for additional styling (e.g., yearly mode indicator)
  if (config.yearDisplayCallback) {
    config.yearDisplayCallback(yearDisplayElement);
  }
}

/**
 * Sets up year navigation buttons with boundary checking
 * @param {Object} config - Configuration object
 * @param {number} config.firstYear - Minimum year boundary
 * @param {number} config.finalYear - Maximum year boundary
 * @param {Function} config.getCalendarYear - Getter for current calendar year
 * @param {Function} config.setCalendarYear - Setter for calendar year
 * @param {Function} config.onYearChange - Callback when year changes
 */
function setupYearNavigation(config) {
  const {
    firstYear,
    finalYear,
    getCalendarYear,
    setCalendarYear,
    onYearChange
  } = config;

  document.getElementById('prev-year-button').addEventListener('click', () => {
    const currentYear = getCalendarYear();
    if (currentYear > firstYear) {
      setCalendarYear(currentYear - 1);
      onYearChange();
    }
  });

  document.getElementById('next-year-button').addEventListener('click', () => {
    const currentYear = getCalendarYear();
    if (currentYear < finalYear) {
      setCalendarYear(currentYear + 1);
      onYearChange();
    }
  });
}

/**
 * Updates the month grid buttons with data availability and selection state
 * @param {Object} config - Configuration object
 * @param {number} config.calendarYear - Current calendar year
 * @param {Set} config.availableMonths - Set of available month strings (YYYY-MM)
 * @param {Function} config.isMonthSelected - Function to check if month is selected
 * @param {Function} config.onMonthClick - Callback when month is clicked
 * @param {boolean} [config.disableInteraction] - Disable month selection (e.g., in yearly view)
 */
function updateMonthGrid(config) {
  const {
    calendarYear,
    availableMonths,
    isMonthSelected,
    onMonthClick,
    disableInteraction = false
  } = config;

  const monthButtons = document.querySelectorAll('.month-btn');

  monthButtons.forEach((btn, index) => {
    const monthStr = formatMonthString(calendarYear, index);
    const hasData = availableMonths.has(monthStr);

    // Update visual state
    btn.classList.toggle('has-data', hasData);
    btn.classList.toggle('selected', isMonthSelected(index));
    btn.disabled = !hasData;

    // Apply interaction override if needed
    if (disableInteraction) {
      btn.style.pointerEvents = 'none';
      btn.style.opacity = '0.5';
    } else {
      btn.style.pointerEvents = 'auto';
      btn.style.opacity = '1';
    }

    // Remove existing click handler
    btn.onclick = null;

    // Add new click handler if data exists
    if (hasData) {
      btn.onclick = () => onMonthClick(index);
    }
  });
}
