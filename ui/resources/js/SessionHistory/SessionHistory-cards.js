// ===== DATA AGGREGATION FOR BY DAY/MONTH VIEWS =====

// Get games played on a specific date
function getGamesForDate(dateStr) {
  const sessionsOnDate = allSessions.filter(session => {
    const sessionDate = new Date(session.start_time * 1000);
    const sessionDateStr = sessionDate.toISOString().split('T')[0];
    return sessionDateStr === dateStr;
  });

  // Group by game
  const gameMap = {};
  sessionsOnDate.forEach(session => {
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

// Get games played in a specific month
function getGamesForMonth(monthStr) {
  const sessionsInMonth = allSessions.filter(session => {
    const sessionDate = new Date(session.start_time * 1000);
    const sessionMonthStr = sessionDate.toISOString().substring(0, 7);
    return sessionMonthStr === monthStr;
  });

  // Group by game
  const gameMap = {};
  sessionsInMonth.forEach(session => {
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

  // Update stats
  const totalGames = games.length;
  const totalMinutes = games.reduce((sum, game) => sum + game.totalDuration, 0);
  const totalHours = (totalMinutes / 60).toFixed(1);

  document.getElementById('total-games-count').textContent =
    `${totalGames} game${totalGames !== 1 ? 's' : ''}`;
  document.getElementById('total-time-played').textContent =
    `${totalHours}h total`;

  // Render cards
  renderGameCards(games);
}

// Load and render game cards for a specific month
function loadGameCardsForMonth(monthStr) {
  const games = getGamesForMonth(monthStr);

  // Update header
  const [year, month] = monthStr.split('-');
  const monthNames = ['January', 'February', 'March', 'April', 'May', 'June',
                      'July', 'August', 'September', 'October', 'November', 'December'];
  const monthDisplay = `${monthNames[parseInt(month) - 1]} ${year}`;

  document.getElementById('selected-date-title').textContent =
    `Games Played in ${monthDisplay}`;

  // Update stats
  const totalGames = games.length;
  const totalMinutes = games.reduce((sum, game) => sum + game.totalDuration, 0);
  const totalHours = (totalMinutes / 60).toFixed(1);

  document.getElementById('total-games-count').textContent =
    `${totalGames} game${totalGames !== 1 ? 's' : ''}`;
  document.getElementById('total-time-played').textContent =
    `${totalHours}h total`;

  // Render cards
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
