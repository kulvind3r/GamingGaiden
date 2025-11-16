// ===== DATA AGGREGATION FOR BY DAY/MONTH VIEWS =====

// Get games played on a specific date
function getGamesForDate(dateStr) {
  const sessionsOnDate = filterSessionsByDateStr(dateStr, false);
  return aggregateGamesBySessions(sessionsOnDate);
}

// Get games played in a specific month
function getGamesForMonth(monthStr) {
  const sessionsInMonth = filterSessionsByDateStr(monthStr, true);
  return aggregateGamesBySessions(sessionsInMonth);
}

// ===== GAME CARDS LOADING & RENDERING =====

// Load and render game cards for a specific date
function loadGameCardsForDate(dateStr) {
  const games = getGamesForDate(dateStr);

  // Update header
  const date = new Date(dateStr);
  const dateDisplay = date.toLocaleDateString('en-US', {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric'
  });

  document.getElementById('selected-date-title').textContent =
    `Games Played on ${dateDisplay}`;

  // Update stats and render
  updateStatsDisplay(games);
  renderGameCards(games);
}

// Load and render game cards for a specific month
function loadGameCardsForMonth(monthStr) {
  const games = getGamesForMonth(monthStr);

  // Update header
  const [year, month] = monthStr.split('-');
  const monthDisplay = `${MONTH_NAMES[parseInt(month) - 1]} ${year}`;

  document.getElementById('selected-date-title').textContent =
    `Games Played in ${monthDisplay}`;

  // Update stats and render
  updateStatsDisplay(games);
  renderGameCards(games);
}

// Update grid alignment based on overflow
function updateGridAlignment() {
  const gridElement = document.getElementById('game-cards-grid');

  // Use setTimeout to ensure DOM has updated and measurements are accurate
  setTimeout(() => {
    const hasOverflow = gridElement.scrollHeight > gridElement.clientHeight;

    if (hasOverflow) {
      gridElement.classList.remove('centered');
    } else {
      gridElement.classList.add('centered');
    }
  }, 0);
}

// Render game cards grid
function renderGameCards(games) {
  const gridElement = document.getElementById('game-cards-grid');
  const noGamesMsg = document.getElementById('no-games-message');

  if (games.length === 0) {
    gridElement.innerHTML = '';
    noGamesMsg.style.display = 'flex';
    gridElement.classList.remove('centered');
    return;
  }

  noGamesMsg.style.display = 'none';
  gridElement.innerHTML = '';

  games.forEach(game => {
    const card = document.createElement('div');
    card.className = 'game-card';
    card.dataset.gameName = game.game_name;

    const hours = (game.totalDuration / 60).toFixed(1);
    const sessionsText = game.sessionCount === 1 ? 'session' : 'sessions';

    card.innerHTML = `
      <img src="${game.icon}" class="game-card-icon" alt="${game.game_name}">
      <div class="game-card-name">${game.game_name}</div>
      <div class="game-card-platform">${game.platform}</div>
      <div class="game-card-stats">${game.sessionCount} ${sessionsText} • ${hours}h</div>
    `;

    // Click handler: switch to games view and select this game
    card.addEventListener('click', () => {
      switchMainView('games');
      selectGame(game.game_name);
    });

    gridElement.appendChild(card);
  });

  // Update alignment after cards are rendered
  updateGridAlignment();
}
