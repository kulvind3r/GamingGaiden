/* eslint-disable no-unused-vars */
/*global formatMonthString, formatDateString, updateYearDisplay, setupYearNavigation, updateMonthGrid, availableDates, availableMonths, maxDate, minDate, MONTH_NAMES, loadGameCardsForDate, loadGameCardsForMonth, mainView:writable, calendarYear:writable, calendarMonth:writable, calendarDay:writable */
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

// Switch between main views (games, byday, bymonth)
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

  // Show/hide day grid based on view
  document.getElementById('day-grid-container').style.display =
    view === 'byday' ? 'block' : 'none';

  if (view === 'byday') {
    // Initialize to most recent date with data
    initializeByDayView();
  } else if (view === 'bymonth') {
    // Initialize to most recent month with data
    initializeByMonthView();
  }
}

// Initialize By Day view with most recent date
function initializeByDayView() {
  if (maxDate) {
    calendarYear = maxDate.getFullYear();
    calendarMonth = maxDate.getMonth();
    calendarDay = maxDate.getDate();
  }

  refreshYearDisplay();
  refreshMonthGrid();
  updateDayGrid();

  // Load game cards for the most recent date
  const dateStr = formatDateString(calendarYear, calendarMonth, calendarDay);
  loadGameCardsForDate(dateStr);
}

// Initialize By Month view with most recent month
function initializeByMonthView() {
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

// Setup year navigation
function initYearNavigation() {
  setupYearNavigation({
    firstYear: minDate ? minDate.getFullYear() : 0,
    finalYear: maxDate ? maxDate.getFullYear() : 9999,
    getCalendarYear: () => calendarYear,
    setCalendarYear: (year) => { calendarYear = year; },
    onYearChange: () => {
      refreshYearDisplay();
      refreshMonthGrid();
      if (mainView === 'byday') {
        updateDayGrid();
      }
    }
  });
}

// Update year display (wrapper)
function refreshYearDisplay() {
  updateYearDisplay(calendarYear);
}

// Update month grid (wrapper)
function refreshMonthGrid() {
  updateMonthGrid({
    calendarYear: calendarYear,
    availableMonths: availableMonths,
    isMonthSelected: (monthIndex) => monthIndex === calendarMonth,
    onMonthClick: (monthIndex) => {
      calendarMonth = monthIndex;
      refreshMonthGrid();

      if (mainView === 'byday') {
        // Find first day with data in this month
        const daysInMonth = new Date(calendarYear, calendarMonth + 1, 0).getDate();
        for (let day = 1; day <= daysInMonth; day++) {
          const dateStr = formatDateString(calendarYear, calendarMonth, day);
          if (availableDates.has(dateStr)) {
            calendarDay = day;
            break;
          }
        }
        updateDayGrid();
        const dateStr = formatDateString(calendarYear, calendarMonth, calendarDay);
        loadGameCardsForDate(dateStr);
      } else if (mainView === 'bymonth') {
        const monthStr = formatMonthString(calendarYear, calendarMonth);
        loadGameCardsForMonth(monthStr);
      }
    }
  });
}

// Update day grid for selected month
function updateDayGrid() {
  const dayGrid = document.getElementById('day-grid');
  dayGrid.innerHTML = '';

  // Update selected month display
  document.getElementById('selected-month-display').textContent =
    `${MONTH_NAMES[calendarMonth]} ${calendarYear}`;

  // Get first day of month and number of days
  const firstDay = new Date(calendarYear, calendarMonth, 1).getDay();
  const daysInMonth = new Date(calendarYear, calendarMonth + 1, 0).getDate();

  // Add empty cells for days before month starts
  for (let i = 0; i < firstDay; i++) {
    const emptyBtn = document.createElement('button');
    emptyBtn.className = 'day-btn empty';
    emptyBtn.disabled = true;
    dayGrid.appendChild(emptyBtn);
  }

  // Add day buttons
  for (let day = 1; day <= daysInMonth; day++) {
    const dateStr = formatDateString(calendarYear, calendarMonth, day);
    const hasData = availableDates.has(dateStr);
    const dayOfWeek = new Date(calendarYear, calendarMonth, day).getDay();
    const isWeekend = dayOfWeek === 0 || dayOfWeek === 6; // Sunday or Saturday

    const dayBtn = document.createElement('button');
    dayBtn.className = 'day-btn';
    dayBtn.textContent = day;

    if (hasData) {
      dayBtn.classList.add('has-data');
    }

    if (calendarDay === day) {
      dayBtn.classList.add('selected');
    }

    if (isWeekend) {
      dayBtn.classList.add('weekend');
    }

    dayBtn.disabled = !hasData;

    if (hasData) {
      dayBtn.addEventListener('click', () => {
        calendarDay = day;
        updateDayGrid();
        loadGameCardsForDate(dateStr);
      });
    }

    dayGrid.appendChild(dayBtn);
  }
}
