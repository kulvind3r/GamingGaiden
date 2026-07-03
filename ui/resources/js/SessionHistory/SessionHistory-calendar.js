/* eslint-disable no-unused-vars */
/*global formatMonthString, updateYearDisplay, setupYearNavigation, updateMonthGrid, availableMonths, maxDate, minDate, loadGameCardsForMonth, loadGameCardsForYear, mainView:writable, sessionHistoryByMonthMode:writable, calendarYear:writable, calendarMonth:writable */
/*from calendar-controls.js, SessionHistory-shared.js, SessionHistory-cards.js */

// ===== MAIN VIEW SWITCHING =====

// Setup main view buttons
function setupMainViewButtons() {
  document.querySelectorAll('.view-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const view = btn.dataset.view;
      switchMainView(view);
    });
  });
}

// Switch between main views (games, bymonth)
function switchMainView(view) {
  mainView = view;

    // Update button active states
  document.querySelectorAll('.view-btn').forEach(btn => {
    btn.classList.toggle('active', btn.dataset.view === view);
   });

    // Show/hide left column content
  document.getElementById('games-view-content').style.display =
    view === 'games' ? 'flex' : 'none';
  document.getElementById('calendar-view-content').style.display =
    view !== 'games' ? 'flex' : 'none';

    // Show/hide right column content
  document.getElementById('games-view-right').style.display =
    view === 'games' ? 'flex' : 'none';
  document.getElementById('cards-view-right').style.display =
    view !== 'games' ? 'flex' : 'none';

  if (view === 'bymonth') {
     // Initialize to most recent month with data
    initializeByMonthView();
   }
}

// Initialize By Month view with most recent month
function initializeByMonthView() {
  sessionHistoryByMonthMode = 'monthly';

  if (maxDate) {
    calendarYear = maxDate.getFullYear();
    calendarMonth = maxDate.getMonth();
  }

  refreshYearDisplay();
  refreshMonthGrid();

  // Load game cards for the most recent month
  const monthStr = formatMonthString(calendarYear, calendarMonth);
  loadGameCardsForMonth(monthStr);
}

// ===== CALENDAR NAVIGATION =====

/** Latest month index (0–11) in `year` with session data, or null if none */
function latestMonthIndexWithDataForYear(year) {
  for (let m = 11; m >= 0; m--) {
    if (availableMonths.has(formatMonthString(year, m))) {
      return m;
    }
  }
  return null;
}

/** By Month + monthly: after year changes, pick latest month with data, else January */
function applyMonthSelectionAfterYearChangeForByMonth() {
  if (mainView !== 'bymonth' || sessionHistoryByMonthMode !== 'monthly') {
    return;
  }
  const latest = latestMonthIndexWithDataForYear(calendarYear);
  calendarMonth = latest !== null ? latest : 0;
}

// Setup year navigation
function initYearNavigation() {
  setupYearNavigation({
    firstYear: minDate ? minDate.getFullYear() : 0,
    finalYear: maxDate ? maxDate.getFullYear() : 9999,
    getCalendarYear: () => calendarYear,
    setCalendarYear: (year) => { calendarYear = year; },
    onYearChange: () => {
      applyMonthSelectionAfterYearChangeForByMonth();
      refreshYearDisplay();
      refreshMonthGrid();
      if (mainView === 'bymonth') {
        if (sessionHistoryByMonthMode === 'yearly') {
          loadGameCardsForYear(calendarYear);
           } else {
           const monthStr = formatMonthString(calendarYear, calendarMonth);
           loadGameCardsForMonth(monthStr);
           }
         }
       }
  });
}

// Toggle monthly vs yearly game list in By Month view (click year — same idea as Gaming Time)
function setupByMonthYearToggle() {
document.getElementById('year-display').addEventListener('click', () => {
  if (mainView !== 'bymonth') {
    return;
    }
  if (sessionHistoryByMonthMode === 'monthly') {
    sessionHistoryByMonthMode = 'yearly';
    loadGameCardsForYear(calendarYear);
    } else {
     sessionHistoryByMonthMode = 'monthly';
     const monthStr = formatMonthString(calendarYear, calendarMonth);
     loadGameCardsForMonth(monthStr);
    }
  refreshYearDisplay();
  refreshMonthGrid();
  });
}

// Update year display (wrapper)
function refreshYearDisplay() {
updateYearDisplay(calendarYear, {
  yearDisplayCallback: (element) => {
    if (mainView === 'bymonth' && sessionHistoryByMonthMode === 'yearly') {
      element.classList.add('yearly-mode');
      } else {
       element.classList.remove('yearly-mode');
      }
    }
  });
}

// Update month grid (wrapper)
function refreshMonthGrid() {
const byMonthYearly =
  mainView === 'bymonth' && sessionHistoryByMonthMode === 'yearly';

updateMonthGrid({
  calendarYear: calendarYear,
  availableMonths: availableMonths,
  isMonthSelected: (monthIndex) =>
     !byMonthYearly && monthIndex === calendarMonth,
  disableInteraction: byMonthYearly,
  onMonthClick: (monthIndex) => {
    calendarMonth = monthIndex;
    refreshMonthGrid();

    if (mainView === 'bymonth') {
      sessionHistoryByMonthMode = 'monthly';
      const monthStr = formatMonthString(calendarYear, calendarMonth);
      loadGameCardsForMonth(monthStr);
      refreshYearDisplay();
     }
    }
  });
}
