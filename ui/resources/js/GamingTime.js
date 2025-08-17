/*global ChartDataLabels, Chart, chartTitleConfig, gamingData, Log2Axis*/
/*from chart.js, common.js and html template*/

let selectedYear;
let selectedMonth;
let firstYear;
let firstMonth;
let finalYear;
let finalMonth;
let chart;
let summaryPeriod = "monthly";
let periodLabel = "Day of Month";

Log2Axis.id = "log2";
Log2Axis.defaults = {};
Chart.register(Log2Axis);

function formatTime(minutes) {
  if (minutes === 0 || minutes === null) return "0m";
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  return h > 0 ? `${h}h ${m}m` : `${m}m`;
}

function processDataForChart(targetYear, targetMonth, isYearly) {
  const filteredData = gamingData.filter(d => {
    const date = new Date(d.play_date);
    if (isYearly) {
      return date.getFullYear() === targetYear;
    }
    return date.getFullYear() === targetYear && date.getMonth() === targetMonth;
  });

  const labels = [];
  const games = [...new Set(filteredData.map(d => d.game_name))];
  const colors = [...new Set(filteredData.map(d => d.color_hex))];
  const gameColorMap = Object.fromEntries(games.map((g, i) => [g, colors[i]]));

  const datasets = games.map(game => ({
    label: game,
    data: [],
    backgroundColor: gameColorMap[game],
  }));

  if (isYearly) {
    periodLabel = "Month of Year";
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    labels.push(...months);
    months.forEach((month, monthIndex) => {
      const monthData = filteredData.filter(d => new Date(d.play_date).getMonth() === monthIndex);
      games.forEach(game => {
        const totalDuration = monthData
          .filter(d => d.game_name === game)
          .reduce((sum, d) => sum + d.total_duration, 0);
        const dataset = datasets.find(ds => ds.label === game);
        dataset.data.push(totalDuration);
      });
    });
  } else {
    periodLabel = "Day of Month";
    const daysInMonth = new Date(targetYear, targetMonth + 1, 0).getDate();
    for (let i = 1; i <= daysInMonth; i++) {
      labels.push(i);
    }
    labels.forEach(day => {
      const dayData = filteredData.filter(d => new Date(d.play_date).getDate() === day);
      games.forEach(game => {
        const totalDuration = dayData
          .filter(d => d.game_name === game)
          .reduce((sum, d) => sum + d.total_duration, 0);
        const dataset = datasets.find(ds => ds.label === game);
        dataset.data.push(totalDuration);
      });
    });
  }

  return { labels, datasets };
}


function updatePeriodDisplay(year, month, isYearly) {
  let displayString = "";
  if (isYearly) {
    const yearTotal = gamingData
      .filter(d => new Date(d.play_date).getFullYear() === year)
      .reduce((sum, d) => sum + d.total_duration, 0);
    displayString = `${year} : ${formatTime(yearTotal)}`;
  } else {
    const monthTotal = gamingData
      .filter(d => {
        const date = new Date(d.play_date);
        return date.getFullYear() === year && date.getMonth() === month;
      })
      .reduce((sum, d) => sum + d.total_duration, 0);
    let monthString = new Date(year, month).toLocaleDateString("en-US", { year: 'numeric', month: 'long' });
    displayString = `${monthString} : ${formatTime(monthTotal)}`;
  }
  document.getElementById("time-period-display").innerText = displayString;
  updateWarnMessage("");
}


function updateWarnMessage(message) {
  document.getElementById("warn-msg").innerText = message;
}

function updateChart(year, month, isYearly = false) {
  const { labels, datasets } = processDataForChart(year, month, isYearly);

  if (chart) {
    chart.destroy();
  }

  const ctx = document.getElementById("gaming-time-chart").getContext("2d");

  chart = new Chart(ctx, {
    type: "bar",
    plugins: [ChartDataLabels],
    data: {
      labels: labels,
      datasets: datasets,
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      scales: {
        y: {
          stacked: true,
          beginAtZero: true,
          title: chartTitleConfig("PlayTime", 15),
          ticks: {
            callback: function(value) {
              const hours = Math.floor(value / 60);
              if (value > 0 && value % 60 === 0) return `${hours}h`;
              if (value === 0) return 0;
            }
          }
        },
        yRight: {
          position: "right",
          grid: { display: false },
          ticks: { color: "white" }
        },
        x: {
          stacked: true,
          title: chartTitleConfig(periodLabel, 15),
        },
      },
      plugins: {
        tooltip: {
          callbacks: {
            label: function(context) {
              let label = context.dataset.label || '';
              if (label) {
                label += ': ';
              }
              if (context.parsed.y !== null) {
                label += formatTime(context.parsed.y);
              }
              return label;
            }
          }
        },
        legend: {
          display: true,
          position: 'bottom',
        },
        datalabels: {
          display: function(context) {
            return context.dataset.data[context.dataIndex] > 0;
          },
          formatter: function(value) {
            return formatTime(value);
          },
          color: "#FFFFFF",
          font: {
            family: "monospace",
            weight: "bold"
          },
        },
      }
    },
  });
  updatePeriodDisplay(year, month, isYearly);
}

function switchToNext() {
  if (summaryPeriod === 'monthly') {
    if (selectedMonth === finalMonth && selectedYear === finalYear) {
      updateWarnMessage("No More Data"); return;
    }
    selectedMonth++;
    if (selectedMonth > 11) {
      selectedMonth = 0;
      selectedYear++;
    }
  } else {
    if (selectedYear === finalYear) {
      updateWarnMessage("No More Data"); return;
    }
    selectedYear++;
  }
  updateChart(selectedYear, selectedMonth, summaryPeriod === 'yearly');
}

function switchToPrev() {
  if (summaryPeriod === 'monthly') {
    if (selectedMonth === firstMonth && selectedYear === firstYear) {
      updateWarnMessage("No More Data"); return;
    }
    selectedMonth--;
    if (selectedMonth < 0) {
      selectedMonth = 11;
      selectedYear--;
    }
  } else {
    if (selectedYear === firstYear) {
      updateWarnMessage("No More Data"); return;
    }
    selectedYear--;
  }
  updateChart(selectedYear, selectedMonth, summaryPeriod === 'yearly');
}

function toggleSummaryPeriod() {
  if (summaryPeriod === "monthly") {
    summaryPeriod = "yearly";
    document.getElementById("period-button").innerText = "Monthly Summary";
  } else {
    summaryPeriod = "monthly";
    document.getElementById("period-button").innerText = "Yearly Summary";
  }
  updateChart(selectedYear, selectedMonth, summaryPeriod === 'yearly');
}

function initialize() {
  if (gamingData.length === 0) {
    updateWarnMessage("No data to display.");
    return;
  }
  const firstDate = new Date(gamingData[0].play_date);
  const lastDate = new Date(gamingData[gamingData.length - 1].play_date);
  firstYear = firstDate.getFullYear();
  firstMonth = firstDate.getMonth();
  finalYear = lastDate.getFullYear();
  finalMonth = lastDate.getMonth();
  selectedYear = finalYear;
  selectedMonth = finalMonth;

  document.getElementById("prev-button").addEventListener("click", switchToPrev);
  document.getElementById("next-button").addEventListener("click", switchToNext);
  document.getElementById("period-button").addEventListener("click", toggleSummaryPeriod);

  updateChart(selectedYear, selectedMonth, false);
}

initialize();
