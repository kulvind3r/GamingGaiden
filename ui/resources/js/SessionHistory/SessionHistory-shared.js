/*global Chart, ChartDataLabels, chartTitleConfig, getChartTextColor, getChartGridColor*/

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

// Shared constants
const MONTH_NAMES = ['January', 'February', 'March', 'April', 'May', 'June',
                     'July', 'August', 'September', 'October', 'November', 'December'];

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
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    const dateStr = `${year}-${month}-${day}`; // YYYY-MM-DD
    const monthStr = `${year}-${month}`; // YYYY-MM

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

// ===== SHARED HELPER FUNCTIONS =====

// Filter sessions by date string (YYYY-MM-DD) or month string (YYYY-MM)
function filterSessionsByDateStr(dateStr, isMonth = false) {
  return allSessions.filter(session => {
    const sessionDate = new Date(session.start_time * 1000);
    const year = sessionDate.getFullYear();
    const month = String(sessionDate.getMonth() + 1).padStart(2, '0');
    const day = String(sessionDate.getDate()).padStart(2, '0');
    const sessionStr = isMonth
      ? `${year}-${month}`
      : `${year}-${month}-${day}`;
    return sessionStr === dateStr;
  });
}

// Group sessions by game and aggregate stats
function aggregateGamesBySessions(sessions) {
  const gameMap = {};

  sessions.forEach(session => {
    if (!gameMap[session.game_name]) {
      const gameInfo = gamesList.find(g => g.game_name === session.game_name);
      gameMap[session.game_name] = {
        game_name: session.game_name,
        platform: session.platform,
        icon: gameInfo ? gameInfo.icon : '',
        sessions: [],
        sessionCount: 0,
        totalDuration: 0,
        lastPlayed: 0
      };
    }

    gameMap[session.game_name].sessions.push(session);
    gameMap[session.game_name].sessionCount++;
    gameMap[session.game_name].totalDuration += session.duration;
    gameMap[session.game_name].lastPlayed = Math.max(
      gameMap[session.game_name].lastPlayed,
      session.start_time
    );
  });

  // Convert to array and sort by last played
  return Object.values(gameMap).sort((a, b) => b.lastPlayed - a.lastPlayed);
}

// Update total games and hours stats in UI
function updateStatsDisplay(games) {
  const totalGames = games.length;
  const totalMinutes = games.reduce((sum, game) => sum + game.totalDuration, 0);
  const totalHours = (totalMinutes / 60).toFixed(1);

  document.getElementById('total-games-count').textContent =
    `${totalGames} game${totalGames !== 1 ? 's' : ''}`;
  document.getElementById('total-time-played').textContent =
    `${totalHours}h total`;
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
