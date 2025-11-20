// ===== GAMES VIEW - LIST MANAGEMENT =====

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

// ===== GAMES VIEW - GAME SELECTION & STATS =====

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

// ===== GAMES VIEW - SESSION GROUPING =====

// Group sessions by day and sum durations
function groupSessionsByDay(sessions) {
  const grouped = {};

  sessions.forEach((session) => {
    const date = new Date(session.start_time * 1000);
    const dayKey = date.toLocaleDateString(); // e.g., "1/15/2025"

    if (!grouped[dayKey]) {
      grouped[dayKey] = {
        date: dayKey,
        timestamp: session.start_time,
        totalDuration: 0,
        sessionCount: 0,
        sessions: []
      };
    }

    grouped[dayKey].totalDuration += session.duration;
    grouped[dayKey].sessionCount += 1;
    grouped[dayKey].sessions.push(session);
  });

  // Convert to array and sort by timestamp (ascending: oldest → newest)
  return Object.values(grouped).sort((a, b) =>
    a.timestamp - b.timestamp
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

// ===== GAMES VIEW - CHART TOGGLES & NAVIGATION =====

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

// ===== GAMES VIEW - CHART RENDERING =====

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
    plugins: [ChartDataLabels],
    data: {
      labels: labels,
      datasets: [
        {
          label: "Play Time",
          data: durations,
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
          display: false
        },
        tooltip: {
          callbacks: {
            title: function (context) {
              return context[0].label;
            },
            label: function (context) {
              const dayData = sessionsByDay[context.dataIndex];
              const sessionsText = dayData.sessionCount === 1 ? "session" : "sessions";
              return `${dayData.sessionCount} ${sessionsText}`;
            }
          }
        },
        datalabels: {
          anchor: "end",
          align: "top",
          formatter: function (value) {
            return value != 0 ? value : "";
          },
          color: "#000000",
          font: {
            family: "monospace"
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

// ===== DAY/NIGHT VISUALIZATION =====

// Calculate approximate day/night hours based on timezone
function getDayNightHours() {
  const offset = new Date().getTimezoneOffset() / -60; // UTC offset in hours

  // Approximate sunrise/sunset based on timezone
  // Base assumption: UTC+0 has sunrise at 6:00, sunset at 18:00
  // Adjust for timezone offset (simplified approximation)
  const baseSunrise = 6;
  const baseSunset = 18;

  // Simple adjustment: shift hours slightly based on timezone
  // Keep within reasonable bounds (4-8 for sunrise, 16-20 for sunset)
  const dayStart = Math.max(4, Math.min(8, baseSunrise + Math.round(offset / 4)));
  const dayEnd = Math.max(16, Math.min(20, baseSunset + Math.round(offset / 4)));

  return { dayStart, dayEnd };
}

// Custom plugin for day/night background zones with gradients, stars, and symbols
const dayNightZonesPlugin = {
  id: 'dayNightZones',
  beforeDraw: (chart, args, options) => {
    if (!options.enabled) return;

    const { ctx, chartArea, scales: { x } } = chart;
    const { top, bottom, left, right } = chartArea;
    const { dayStart, dayEnd } = options;
    const height = bottom - top;

    ctx.save();

    // Color definitions
    const nightBlue = 'rgba(10, 20, 100, 0.3)';  // More blue, darker, less gray
    const dayYellow = 'rgba(255, 240, 200, 0.12)';  // Warm yellow
    const transitionOrange = 'rgba(255, 140, 80, 0.2)';

    // Transition boundaries (2 hour transitions for longer gradient)
    const dawnStart = dayStart - 1;
    const dawnEnd = dayStart + 1;
    const duskStart = dayEnd - 1;
    const duskEnd = dayEnd + 1;

    // === DRAW ZONES ===

    // 1. Early night zone (chart start to dawn start)
    if (dawnStart > 0) {
      const xStart = left;  // Start from chart edge, not hour 0
      const xEnd = x.getPixelForValue(dawnStart);
      ctx.fillStyle = nightBlue;
      ctx.fillRect(xStart, top, xEnd - xStart, height);
    }

    // 2. Dawn transition (gradient from night to day)
    const dawnXStart = x.getPixelForValue(Math.max(0, dawnStart));
    const dawnXEnd = x.getPixelForValue(dawnEnd);
    const dawnGradient = ctx.createLinearGradient(dawnXStart, 0, dawnXEnd, 0);
    dawnGradient.addColorStop(0, nightBlue);
    dawnGradient.addColorStop(0.5, transitionOrange);
    dawnGradient.addColorStop(1, dayYellow);
    ctx.fillStyle = dawnGradient;
    ctx.fillRect(dawnXStart, top, dawnXEnd - dawnXStart, height);

    // 3. Day zone (after dawn to before dusk)
    const dayXStart = x.getPixelForValue(dawnEnd);
    const dayXEnd = x.getPixelForValue(duskStart);
    ctx.fillStyle = dayYellow;
    ctx.fillRect(dayXStart, top, dayXEnd - dayXStart, height);

    // 4. Dusk transition (gradient from day to night)
    const duskXStart = x.getPixelForValue(duskStart);
    const duskXEnd = x.getPixelForValue(Math.min(24, duskEnd));
    const duskGradient = ctx.createLinearGradient(duskXStart, 0, duskXEnd, 0);
    duskGradient.addColorStop(0, dayYellow);
    duskGradient.addColorStop(0.5, transitionOrange);
    duskGradient.addColorStop(1, nightBlue);
    ctx.fillStyle = duskGradient;
    ctx.fillRect(duskXStart, top, duskXEnd - duskXStart, height);

    // 5. Late night zone (after dusk to chart end)
    if (duskEnd < 24) {
      const xStart = x.getPixelForValue(duskEnd);
      const xEnd = right;  // Extend to chart edge, not just hour 24
      ctx.fillStyle = nightBlue;
      ctx.fillRect(xStart, top, xEnd - xStart, height);
    }

    // === DRAW STARS in night zones ===
    // Generate consistent star positions using pseudo-random based on chart dimensions
    const starCount = 20;
    const seed = 12345; // Fixed seed for consistency
    const starSize = Math.min(12, height * 0.04); // Scale with chart height

    // Simple pseudo-random number generator
    let random = seed;
    const pseudoRandom = () => {
      random = (random * 9301 + 49297) % 233280;
      return random / 233280;
    };

    ctx.font = `${starSize}px Arial`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';

    // Avoid top 10% and bottom 10% of chart area
    const safeTop = top + height * 0.1;
    const safeHeight = height * 0.8;

    // Early night zone stars - more evenly distributed
    if (dawnStart > 0) {
      const nightXStart = left;
      const nightXEnd = x.getPixelForValue(dawnStart);
      const nightWidth = nightXEnd - nightXStart;
      const starsInZone = Math.ceil(starCount / 2);

      // Create grid-based distribution with randomness
      const cols = Math.ceil(Math.sqrt(starsInZone * (nightWidth / safeHeight)));
      const rows = Math.ceil(starsInZone / cols);

      for (let i = 0; i < starsInZone; i++) {
        const col = i % cols;
        const row = Math.floor(i / cols);
        const cellWidth = nightWidth / cols;
        const cellHeight = safeHeight / rows;

        // Add randomness within each cell for natural look
        const starX = nightXStart + col * cellWidth + pseudoRandom() * cellWidth;
        const starY = safeTop + row * cellHeight + pseudoRandom() * cellHeight;
        ctx.fillText('⭐', starX, starY);
      }
    }

    // Late night zone stars - more evenly distributed
    if (duskEnd < 24) {
      const nightXStart = x.getPixelForValue(duskEnd);
      const nightXEnd = right;
      const nightWidth = nightXEnd - nightXStart;
      const starsInZone = Math.floor(starCount / 2);

      // Create grid-based distribution with randomness
      const cols = Math.ceil(Math.sqrt(starsInZone * (nightWidth / safeHeight)));
      const rows = Math.ceil(starsInZone / cols);

      for (let i = 0; i < starsInZone; i++) {
        const col = i % cols;
        const row = Math.floor(i / cols);
        const cellWidth = nightWidth / cols;
        const cellHeight = safeHeight / rows;

        // Add randomness within each cell for natural look
        const starX = nightXStart + col * cellWidth + pseudoRandom() * cellWidth;
        const starY = safeTop + row * cellHeight + pseudoRandom() * cellHeight;
        ctx.fillText('⭐', starX, starY);
      }
    }

    // === DRAW SUN AND MOON SYMBOLS ===
    const symbolSize = Math.min(32, height * 0.15); // Scale with chart height
    const symbolYPosition = top + height * 0.15; // Position at 15% from top
    ctx.font = `${symbolSize}px Arial`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'top';

    // Calculate center of day hours and 2nd hour of night
    const dayCenter = (dawnEnd + duskStart) / 2;

    // Calculate 2nd hour of night (early night zone)
    // Night goes from 0 to dawnStart, so 2nd hour is at hour 2 (if dawnStart > 2)
    const nightHour2 = Math.min(2, dawnStart - 1);

    // Moon at 2nd hour of night
    const moonX = x.getPixelForValue(nightHour2);
    if (moonX >= left && moonX <= right) {
      ctx.fillText('🌙', moonX, symbolYPosition);
    }

    // Sun at center of day hours
    const sunX = x.getPixelForValue(dayCenter);
    if (sunX >= left && sunX <= right) {
      ctx.fillText('☀️', sunX, symbolYPosition);
    }

    ctx.restore();
  }
};

// Register the plugin
Chart.register(dayNightZonesPlugin);

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

  // Get day/night hours based on timezone
  const { dayStart, dayEnd } = getDayNightHours();

  // Sort sessions chronologically and create horizontal timeline bars
  const sortedSessions = [...dayData.sessions].sort((a, b) => a.start_time - b.start_time);
  const timelineData = [];

  sortedSessions.forEach((session, index) => {
    const startDate = new Date(session.start_time * 1000);
    const hour = startDate.getHours();
    const minute = startDate.getMinutes();
    const startTime = hour + (minute / 60); // Decimal hours (e.g., 14.5 for 14:30)
    const durationHours = session.duration / 60; // Convert minutes to hours
    const endTime = startTime + durationHours;

    timelineData.push({
      y: "Timeline", // All sessions on same row
      x: [startTime, endTime], // Floating bar: [start, end]
      duration: parseFloat(durationHours.toFixed(2)), // For data label
      session: session
    });
  });

  currentChart = new Chart(ctx, {
    type: "bar",
    plugins: [ChartDataLabels],
    data: {
      datasets: [
        {
          label: "Session Duration (Hours)",
          data: timelineData,
          borderWidth: 2,
          borderSkipped: false,
          barThickness: 75
        }
      ]
    },
    options: {
      indexAxis: 'y', // Horizontal bars
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        dayNightZones: {
          enabled: true,
          dayStart: dayStart,
          dayEnd: dayEnd,
          nightColor: 'rgba(100, 120, 140, 0.08)'
        },
        title: {
          display: true,
          text: `Hourly Sessions for ${selectedGame} on ${selectedDay}`,
          font: {
            size: 16
          }
        },
        legend: {
          display: false
        },
        tooltip: {
          enabled: false
        },
        datalabels: {
          anchor: "start",
          align: "top",
          offset: 45,
          formatter: function (value) {
            return value.duration != 0 ? value.duration + "h" : "";
          },
          color: "#000000",
          font: {
            family: "monospace"
          }
        }
      },
      scales: {
        y: {
          type: 'category',
          title: {
            display: false,
            text: "Timeline"
          },
          ticks: {
            autoSkip: false,
            align: 'start'
          },
          grid: {
            display: false
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
          },
          grid: {
            offset: false
          }
        }
      }
    }
  });
}
