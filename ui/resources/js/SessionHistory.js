/*global Chart*/

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

// Register custom log2 scale for logarithmic Y-axis
Log2Axis.id = "log2";
Log2Axis.defaults = {};
Chart.register(Log2Axis);

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

// Render games list in left column
function renderGamesList(filteredGames = null) {
  const gamesToRender = filteredGames || gamesList;
  const gamesListElement = document.getElementById("games-list");

  gamesListElement.innerHTML = "";

  gamesToRender.forEach((game) => {
    const li = document.createElement("li");
    li.className = "game-list-item";
    li.dataset.gameName = game.game_name;

    const hours = (game.total_duration / 60).toFixed(1);
    const sessionsText = game.session_count === 1 ? "session" : "sessions";

    li.innerHTML = `
      <img src="${game.icon}" class="game-icon" alt="${game.game_name}">
      <div class="game-info">
        <div class="game-name">${game.game_name}</div>
        <div class="game-meta">
          <span class="platform">${game.platform}</span>
          <span class="stats">${game.session_count} ${sessionsText} • ${hours}h</span>
        </div>
      </div>
    `;

    li.addEventListener("click", () => selectGame(game.game_name));
    gamesListElement.appendChild(li);
  });
}

// Search/filter games
function setupSearch() {
  const searchInput = document.getElementById("game-search");

  searchInput.addEventListener("input", (e) => {
    const searchTerm = e.target.value.toLowerCase();

    if (searchTerm === "") {
      applySortAndRender();
      return;
    }

    const filtered = gamesList.filter((game) =>
      game.game_name.toLowerCase().includes(searchTerm)
    );

    const sorted = sortGamesList(filtered, currentSortField, currentSortDirection);
    renderGamesList(sorted);
  });
}

// Sort games list
function sortGamesList(games, field, direction) {
  return [...games].sort((a, b) => {
    let comparison = 0;

    if (field === 'name') {
      comparison = a.game_name.localeCompare(b.game_name);
    } else if (field === 'lastPlayed') {
      // Get last played dates from allSessions
      const aLastPlayed = Math.max(...allSessions
        .filter(s => s.game_name === a.game_name)
        .map(s => s.start_time));
      const bLastPlayed = Math.max(...allSessions
        .filter(s => s.game_name === b.game_name)
        .map(s => s.start_time));
      comparison = aLastPlayed - bLastPlayed;
    }

    return direction === 'asc' ? comparison : -comparison;
  });
}

// Setup sorting button handlers
function setupSorting() {
  document.getElementById('sort-by-name').addEventListener('click', () => {
    if (currentSortField === 'name') {
      currentSortDirection = currentSortDirection === 'asc' ? 'desc' : 'asc';
    } else {
      currentSortField = 'name';
      currentSortDirection = 'asc';
    }
    updateSortButtons();
    applySortAndRender();
  });

  document.getElementById('sort-by-last-played').addEventListener('click', () => {
    if (currentSortField === 'lastPlayed') {
      currentSortDirection = currentSortDirection === 'asc' ? 'desc' : 'asc';
    } else {
      currentSortField = 'lastPlayed';
      currentSortDirection = 'desc';
    }
    updateSortButtons();
    applySortAndRender();
  });
}

// Update sort button states and arrows
function updateSortButtons() {
  const nameBtn = document.getElementById('sort-by-name');
  const lastPlayedBtn = document.getElementById('sort-by-last-played');

  // Update active state
  nameBtn.classList.toggle('active', currentSortField === 'name');
  lastPlayedBtn.classList.toggle('active', currentSortField === 'lastPlayed');

  // Update arrows
  const nameArrow = nameBtn.querySelector('.sort-arrow');
  const lastPlayedArrow = lastPlayedBtn.querySelector('.sort-arrow');

  nameArrow.textContent = currentSortField === 'name' ? (currentSortDirection === 'asc' ? '▲' : '▼') : '▼';
  lastPlayedArrow.textContent = currentSortField === 'lastPlayed' ? (currentSortDirection === 'asc' ? '▲' : '▼') : '▼';
}

// Apply current sort and render
function applySortAndRender() {
  const sorted = sortGamesList(gamesList, currentSortField, currentSortDirection);
  renderGamesList(sorted);
}

// Select a game and update right column
function selectGame(gameName) {
  selectedGame = gameName;

  // Update active state in list
  document.querySelectorAll(".game-list-item").forEach((item) => {
    if (item.dataset.gameName === gameName) {
      item.classList.add("active");
    } else {
      item.classList.remove("active");
    }
  });

  // Hide "no selection" message
  document.getElementById("no-selection-message").style.display = "none";

  // Update header
  const gameData = gamesList.find((g) => g.game_name === gameName);
  const hours = (gameData.total_duration / 60).toFixed(1);
  const sessionsText = gameData.session_count === 1 ? "session" : "sessions";

  document.getElementById("selected-game-name").innerHTML =
    `${gameName}<img src="${gameData.icon}" class="selected-game-icon" alt="${gameName}">`;

  // Populate individual stats
  document.getElementById("stat-platform").textContent = gameData.platform;
  document.getElementById("stat-sessions").textContent = `${gameData.session_count} ${sessionsText}`;
  document.getElementById("stat-hours").textContent = `${hours} hours`;

  // Filter sessions for this game
  const gameSessions = allSessions.filter((s) => s.game_name === gameName);

  // Group sessions by day
  sessionsByDay = groupSessionsByDay(gameSessions);

  // Initialize date selection for specific date view
  initializeDateSelection();

  // Update last played date
  if (sessionsByDay.length > 0) {
    const lastPlayedDate = sessionsByDay[sessionsByDay.length - 1].date;
    document.getElementById("stat-last-played").textContent = lastPlayedDate;
  }

  // Reset to all time view when selecting a new game
  currentView = 'alltime';
  updateViewToggle();

  // Update chart based on current view
  updateChart();
}

// Group sessions by day and sum durations
function groupSessionsByDay(sessions) {
  const grouped = {};

  sessions.forEach((session) => {
    const date = new Date(session.start_time * 1000);
    const dayKey = date.toLocaleDateString(); // e.g., "1/15/2025"

    if (!grouped[dayKey]) {
      grouped[dayKey] = {
        date: dayKey,
        totalDuration: 0,
        sessionCount: 0,
        sessions: []
      };
    }

    grouped[dayKey].totalDuration += session.duration;
    grouped[dayKey].sessionCount += 1;
    grouped[dayKey].sessions.push(session);
  });

  // Convert to array and sort by date
  return Object.values(grouped).sort((a, b) =>
    new Date(a.date) - new Date(b.date)
  );
}

// Initialize date selection to most recent
function initializeDateSelection() {
  // Select most recent day (last in array) by default
  if (sessionsByDay.length > 0) {
    selectedDayIndex = sessionsByDay.length - 1;
    selectedDay = sessionsByDay[selectedDayIndex].date;
    updateDateDisplay();
  }
}

// Update the date display text
function updateDateDisplay() {
  const dateDisplay = document.getElementById("date-display");
  if (sessionsByDay.length > 0) {
    const dayData = sessionsByDay[selectedDayIndex];
    dateDisplay.textContent = `${dayData.date} (${dayData.sessionCount} session${dayData.sessionCount > 1 ? 's' : ''})`;
  }
}

// Setup view toggle handler (single button)
function setupViewToggle() {
  const toggleButton = document.getElementById("view-toggle-button");

  toggleButton.addEventListener("click", () => {
    if (currentView === 'alltime') {
      currentView = 'specificdate';
    } else {
      currentView = 'alltime';
    }
    updateViewToggle();
    updateChart();
  });
}

// Update view toggle button and navigation bar visibility
function updateViewToggle() {
  const toggleButton = document.getElementById("view-toggle-button");
  const navigationBar = document.getElementById("chart-navigation-bar");

  if (currentView === 'alltime') {
    toggleButton.textContent = "Specific Date";
    navigationBar.style.visibility = "hidden";
  } else {
    toggleButton.textContent = "All time";
    navigationBar.style.visibility = "visible";
  }
}

// Navigate to next date
function switchToNextDate() {
  if (selectedDayIndex >= sessionsByDay.length - 1) {
    return; // Already at most recent date
  }

  selectedDayIndex++;
  selectedDay = sessionsByDay[selectedDayIndex].date;
  updateDateDisplay();
  updateChart();
}

// Navigate to previous date
function switchToPrevDate() {
  if (selectedDayIndex <= 0) {
    return; // Already at oldest date
  }

  selectedDayIndex--;
  selectedDay = sessionsByDay[selectedDayIndex].date;
  updateDateDisplay();
  updateChart();
}

// Setup date navigation buttons
function setupDateNavigation() {
  document.getElementById("prev-date-button").addEventListener("click", switchToPrevDate);
  document.getElementById("next-date-button").addEventListener("click", switchToNextDate);
}

// Update chart based on current view
function updateChart() {
  if (currentView === 'alltime') {
    updateAllTimeChart();
  } else {
    updateSpecificDateChart();
  }
}

// Create/update the all-time bar chart (daily view)
function updateAllTimeChart() {
  const ctx = document.getElementById("session-chart").getContext("2d");

  // Destroy existing chart if it exists
  if (currentChart) {
    currentChart.destroy();
  }

  const labels = sessionsByDay.map((day) => day.date);
  const durations = sessionsByDay.map((day) => (day.totalDuration / 60).toFixed(2)); // Convert to hours

  currentChart = new Chart(ctx, {
    type: "bar",
    data: {
      labels: labels,
      datasets: [
        {
          label: "Play Time (Hours)",
          data: durations,
          backgroundColor: "rgba(54, 162, 235, 0.6)",
          borderColor: "rgba(54, 162, 235, 1)",
          borderWidth: 1
        }
      ]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        title: {
          display: true,
          text: `Session History for ${selectedGame}`,
          font: {
            size: 16
          }
        },
        legend: {
          display: true,
          position: "top"
        },
        tooltip: {
          callbacks: {
            afterLabel: function (context) {
              const dayData = sessionsByDay[context.dataIndex];
              const sessionsText = dayData.sessionCount === 1 ? "session" : "sessions";
              return `${dayData.sessionCount} ${sessionsText}`;
            }
          }
        }
      },
      scales: {
        y: {
          beginAtZero: true,
          type: "log2",
          title: {
            display: true,
            text: "Hours Played"
          },
          ticks: {
            callback: function (value) {
              return value.toFixed(1) + "h";
            }
          }
        },
        x: {
          title: {
            display: true,
            text: "Date"
          }
        }
      }
    }
  });
}

// Create/update the specific date bar chart (hourly view)
function updateSpecificDateChart() {
  const ctx = document.getElementById("session-chart").getContext("2d");

  // Destroy existing chart if it exists
  if (currentChart) {
    currentChart.destroy();
  }

  // Find the selected day's data
  const dayData = sessionsByDay.find((d) => d.date === selectedDay);
  if (!dayData) {
    return;
  }

  // Create hour buckets (0-23) and place sessions
  const hourlyData = [];
  const sessionLabels = [];
  const sessionColors = [];

  dayData.sessions.forEach((session, index) => {
    const startDate = new Date(session.start_time * 1000);
    const hour = startDate.getHours();
    const minute = startDate.getMinutes();
    const timeLabel = `${hour.toString().padStart(2, '0')}:${minute.toString().padStart(2, '0')}`;

    hourlyData.push({
      x: hour + (minute / 60), // Position on hour axis (e.g., 14.5 for 14:30)
      y: parseFloat((session.duration / 60).toFixed(2)), // Duration in hours (2 decimal places)
      label: timeLabel,
      session: session
    });

    sessionLabels.push(timeLabel);

    // Alternate colors for visual distinction
    const colors = [
      'rgba(54, 162, 235, 0.6)',
      'rgba(75, 192, 192, 0.6)',
      'rgba(153, 102, 255, 0.6)',
      'rgba(255, 159, 64, 0.6)',
      'rgba(255, 99, 132, 0.6)'
    ];
    sessionColors.push(colors[index % colors.length]);
  });

  currentChart = new Chart(ctx, {
    type: "bar",
    data: {
      datasets: [
        {
          label: "Session Duration (Hours)",
          data: hourlyData,
          backgroundColor: sessionColors,
          borderColor: sessionColors.map(c => c.replace('0.6', '1')),
          borderWidth: 1,
          barPercentage: 0.5
        }
      ]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        title: {
          display: true,
          text: `Hourly Sessions for ${selectedGame} on ${selectedDay}`,
          font: {
            size: 16
          }
        },
        legend: {
          display: true,
          position: "top"
        },
        tooltip: {
          callbacks: {
            title: function (context) {
              const dataPoint = context[0].raw;
              return `Started at ${dataPoint.label}`;
            },
            label: function (context) {
              const hours = context.raw.y;
              return `Duration: ${hours} Hr`;
            }
          }
        }
      },
      scales: {
        y: {
          beginAtZero: true,
          type: "log2",
          title: {
            display: true,
            text: "Duration (Hours)"
          },
          ticks: {
            callback: function (value) {
              return value.toFixed(1) + "h";
            }
          }
        },
        x: {
          type: 'linear',
          min: 0,
          max: 24,
          title: {
            display: true,
            text: "Hour of Day"
          },
          ticks: {
            stepSize: 1,
            callback: function (value) {
              return value.toString();
            }
          }
        }
      }
    }
  });
}

// Initialize on page load (after jQuery table processing)
$(document).ready(function() {
  parseSessionsData();
  parseGamesData();
  setupSearch();
  setupSorting();
  updateSortButtons();
  applySortAndRender(); // Initial render with default sort (last played, desc)
  setupViewToggle();
  setupDateNavigation();

  // Auto-select first game if available
  if (gamesList.length > 0) {
    // Select first game from sorted list
    const sorted = sortGamesList(gamesList, currentSortField, currentSortDirection);
    selectGame(sorted[0].game_name);
  }
});
