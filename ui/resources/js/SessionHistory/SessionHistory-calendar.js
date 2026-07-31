/* eslint-disable no-unused-vars */
/*global formatMonthString, formatDateString, updateYearDisplay, setupYearNavigation, updateMonthGrid, availableMonths, availableDates, maxDate, minDate, loadGameCardsForMonth, loadGameCardsForYear, loadGameCardsForDay, mainView:writable, sessionHistoryByMonthMode:writable, calendarYear:writable, calendarMonth:writable, selectedDay:writable */
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
  selectedDay = null;

  if (maxDate) {
    calendarYear = maxDate.getFullYear();
    calendarMonth = maxDate.getMonth();
   }

  refreshYearDisplay();
  refreshMonthGrid();
  updateDayGrid();

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
       updateDayGrid();
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
    selectedDay = null;
    loadGameCardsForYear(calendarYear);
   } else {
   sessionHistoryByMonthMode = 'monthly';
   const monthStr = formatMonthString(calendarYear, calendarMonth);
   loadGameCardsForMonth(monthStr);
   }
  refreshYearDisplay();
  refreshMonthGrid();
  updateDayGrid();
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
    selectedDay = null; // Reset day selection when month changes
    refreshMonthGrid();

    if (mainView === 'bymonth') {
      sessionHistoryByMonthMode = 'monthly';
      const monthStr = formatMonthString(calendarYear, calendarMonth);
      loadGameCardsForMonth(monthStr);
      refreshYearDisplay();
      updateDayGrid();
      }
    }
  });
}

// ===== DAY GRID =====

// Update day grid for selected month (interactive - days are clickable)
// Always renders exactly 42 cells (6 rows x 7 columns) to prevent layout shifting
function updateDayGrid() {
const dayGrid = document.getElementById('day-grid');
const dayGridContainer = document.getElementById('day-grid-container');
const selectedMonthDisplay = document.getElementById('selected-month-display');

// Show/hide day grid based on view mode (disable in yearly mode)
if (sessionHistoryByMonthMode === 'yearly') {
  dayGridContainer.style.display = 'none';
  return;
  }

dayGridContainer.style.display = 'block';
dayGrid.innerHTML = '';

// Update selected month display
const MONTH_NAMES = ['January', 'February', 'March', 'April', 'May', 'June',
                        'July', 'August', 'September', 'October', 'November', 'December'];
selectedMonthDisplay.textContent = `${MONTH_NAMES[calendarMonth]} ${calendarYear}`;

// Get first day of month and number of days
const firstDay = new Date(calendarYear, calendarMonth, 1).getDay();
const daysInMonth = new Date(calendarYear, calendarMonth + 1, 0).getDate();

// Total cells needed for a fixed 6-row grid
const TOTAL_CELLS = 42; // 6 rows x 7 columns

// Add empty cells for days before month starts
for (let i = 0; i < firstDay; i++) {
  const emptyCell = document.createElement('div');
  emptyCell.className = 'day-cell empty';
  dayGrid.appendChild(emptyCell);
  }

// Add day cells
for (let day = 1; day <= daysInMonth; day++) {
  const dateStr = formatDateString(calendarYear, calendarMonth, day);
  const hasData = availableDates.has(dateStr);
  const dayOfWeek = new Date(calendarYear, calendarMonth, day).getDay();
  const isWeekend = dayOfWeek === 0 || dayOfWeek === 6; // Sunday or Saturday
  const isSelected = selectedDay === day;

  const dayCell = document.createElement('div');
  dayCell.className = 'day-cell';
  dayCell.textContent = day;
  dayCell.dataset.day = day;

  if (hasData) {
    dayCell.classList.add('has-data');
    }

  if (isWeekend) {
    dayCell.classList.add('weekend');
    }

  if (isSelected) {
    dayCell.classList.add('selected');
    }

   // Make day clickable (only if it has data and we're in monthly mode)
  if (hasData && sessionHistoryByMonthMode === 'monthly') {
    dayCell.classList.add('clickable');
    dayCell.addEventListener('click', () => {
      if (selectedDay === day) {
         // Deselect day - return to month view
        selectedDay = null;
        const monthStr = formatMonthString(calendarYear, calendarMonth);
        loadGameCardsForMonth(monthStr);
        } else {
         // Select this day
        selectedDay = day;
        loadGameCardsForDay(dateStr);
        }
       // Refresh day grid to update selection state
      updateDayGrid();
       });
     }

  dayGrid.appendChild(dayCell);
  }

// Add empty cells after the last day to fill the grid to 6 rows (42 cells total)
const totalCellsAdded = firstDay + daysInMonth;
const remainingCells = TOTAL_CELLS - totalCellsAdded;
for (let i = 0; i < remainingCells; i++) {
  const emptyCell = document.createElement('div');
  emptyCell.className = 'day-cell empty';
  dayGrid.appendChild(emptyCell);
  }
}
