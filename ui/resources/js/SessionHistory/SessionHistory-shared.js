/*global Chart*/

// ===== GLOBAL STATE VARIABLES =====

// Parse data from hidden tables
let allSessions = [];
let gamesList = [];
let currentChart = null;
let selectedGame = null;
let currentView = 'alltime'; // 'alltime' or 'specificdate'
let selectedDay = null;
let selectedDayIndex = 0;
let sessionsByDay = [];
let currentSortField = 'lastPlayed'; // 'name' or 'lastPlayed'
let currentSortDirection = 'desc'; // 'asc' or 'desc'

// New state variables for view switching and calendar
let mainView = 'games'; // 'games', 'byday', or 'bymonth'
let calendarYear = new Date().getFullYear();
let calendarMonth = new Date().getMonth();
let calendarDay = null;
let availableDates = new Set(); // Set of 'YYYY-MM-DD' strings
let availableMonths = new Set(); // Set of 'YYYY-MM' strings
let minDate = null;
let maxDate = null;

// Register custom log2 scale for logarithmic Y-axis
Log2Axis.id = "log2";
Log2Axis.defaults = {};
Chart.register(Log2Axis);

// ===== DATA PARSING FUNCTIONS =====

// Parse sessions data
function parseSessionsData() {
  const table = document.getElementById("sessions-data").querySelector("table");
  const rows = table.querySelectorAll("tbody tr");

  allSessions = Array.from(rows).map((row) => {
    return {
      id: row.cells[0].textContent,
      game_name: row.cells[1].textContent,
      platform: row.cells[2].textContent,
      session_date: row.cells[3].textContent,
      start_time: parseInt(row.cells[4].textContent),
      duration: parseFloat(row.cells[5].textContent)
    };
  });

  // Remove header row
  allSessions.shift();
}

// Parse games list data
function parseGamesData() {
  const table = document.getElementById("games-data").querySelector("table");
  const rows = table.querySelectorAll("tbody tr");

  gamesList = Array.from(rows).map((row) => {
    return {
      game_name: row.cells[0].textContent,
      platform: row.cells[1].textContent,
      icon: row.cells[2].textContent,
      session_count: parseInt(row.cells[3].textContent),
      total_duration: parseFloat(row.cells[4].textContent)
    };
  });

  // Remove header row
  gamesList.shift();
}

// ===== DATE AVAILABILITY FUNCTIONS =====

// Build available dates/months set from session data
function buildAvailableDates() {
  availableDates.clear();
  availableMonths.clear();

  let minTimestamp = Infinity;
  let maxTimestamp = -Infinity;

  allSessions.forEach((session) => {
    const date = new Date(session.start_time * 1000);
    const dateStr = date.toISOString().split('T')[0]; // YYYY-MM-DD
    const monthStr = dateStr.substring(0, 7); // YYYY-MM

    availableDates.add(dateStr);
    availableMonths.add(monthStr);

    if (session.start_time < minTimestamp) minTimestamp = session.start_time;
    if (session.start_time > maxTimestamp) maxTimestamp = session.start_time;
  });

  if (minTimestamp !== Infinity) {
    minDate = new Date(minTimestamp * 1000);
    maxDate = new Date(maxTimestamp * 1000);
  }
}

// ===== INITIALIZATION =====

// Initialize on page load (after jQuery table processing)
$(document).ready(function() {
  parseSessionsData();
  parseGamesData();
  buildAvailableDates();
  setupSearch();
  setupSorting();
  updateSortButtons();
  applySortAndRender(); // Initial render with default sort (last played, desc)
  setupViewToggle();
  setupDateNavigation();
  setupMainViewButtons();
  setupYearNavigation();

  // Auto-select first game if available
  if (gamesList.length > 0) {
    // Select first game from sorted list
    const sorted = sortGamesList(gamesList, currentSortField, currentSortDirection);
    selectGame(sorted[0].game_name);
  }

  // Update grid alignment on window resize
  window.addEventListener('resize', updateGridAlignment);
});
