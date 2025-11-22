/*global ChartDataLabels, Chart, chartTitleConfig, buildGamingData, Log2Axis*/
/*from chart.js, common.js*/

let gamingData = [];
let selectedYear;
let selectedMonth;
let firstYear;
let firstMonth;
let finalYear;
let finalMonth;
let chart;
let viewMode = "monthly";
let periodLabel = "Day of Month";
let yearTotalTime;
let monthTotalTime;
let calendarYear;
let availableMonths = new Set();
let availableYears = new Set();

$("table")[0].setAttribute("id", "data-table");

Log2Axis.id = "log2";
Log2Axis.defaults = {};

Chart.register(Log2Axis);

function updatePeriodDisplayWithMonth(selectedYear, selectedMonth) {
  // Display is now handled by calendar selection highlighting
  // Show total hours in warn message area
  updateWarnMessage(parseInt(monthTotalTime) + " Hours Played");
}

function updatePeriodDisplayWithYear(selectedYear) {
  // Display is now handled by calendar year display
  // Show total hours in warn message area
  updateWarnMessage(parseInt(yearTotalTime) + " Hours Played");
}

function updateWarnMessage(message) {
  document.getElementById("total-hours-display").innerText = message;
}

function alignTotalHoursDisplay() {
  if (!chart || !chart.chartArea) {
    return;
  }

  const chartArea = chart.chartArea;
  const plotAreaCenterX = (chartArea.left + chartArea.right) / 2;
  const canvasWidth = chart.canvas.offsetWidth;
  const canvasCenterX = canvasWidth / 2;
  const offsetFromCanvasCenter = plotAreaCenterX - canvasCenterX;

  const totalHoursDiv = document.getElementById('total-hours-display');

  // Apply padding to shift the text to align with plot area center
  if (offsetFromCanvasCenter > 0) {
    totalHoursDiv.style.paddingLeft = `${offsetFromCanvasCenter}px`;
    totalHoursDiv.style.paddingRight = '0px';
  } else {
    totalHoursDiv.style.paddingLeft = '0px';
    totalHoursDiv.style.paddingRight = `${Math.abs(offsetFromCanvasCenter)}px`;
  }

  totalHoursDiv.style.textAlign = 'center';
}

function updateChart(
  selectedYear,
  selectedMonth,
  yearlySummaryEnabled = false
) {
  let labels = [];
  let data = [];
  let datasetData;
  let ylimit;

  if (!yearlySummaryEnabled) {
    monthTotalTime = 0;
    let firstDate = new Date(selectedYear, selectedMonth, 1);
    let lastDate = new Date(selectedYear, selectedMonth + 1, 0);

    for (
      let date = new Date(firstDate);
      date <= lastDate;
      date.setDate(date.getDate() + 1)
    ) {
      labels.push(date.getDate());
      const gamingEntry = gamingData.find((item) => {
        const itemDate = new Date(item.date);
        return (
          itemDate.getFullYear() === selectedYear &&
          itemDate.getMonth() === selectedMonth &&
          itemDate.getDate() === date.getDate()
        );
      });
      data.push(gamingEntry ? (gamingEntry.time / 60).toFixed(1) : 0);
      monthTotalTime =
        monthTotalTime + (gamingEntry ? gamingEntry.time / 60 : 0);
    }

    datasetData = data;
    ylimit = 24;
  } else {
    yearTotalTime = 0;
    labels = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];

    for (let month = 0; month <= 11; month = month + 1) {
      let monthPlayTime = 0;
      gamingData.find((item) => {
        const itemDate = new Date(item.date);
        if (
          itemDate.getFullYear() === selectedYear &&
          itemDate.getMonth() === month
        ) {
          monthPlayTime = monthPlayTime + item.time;
        }
      });
      data.push({
        month: labels.at(month),
        time: (monthPlayTime / 60).toFixed(1),
      });
      yearTotalTime = yearTotalTime + monthPlayTime / 60;
    }

    datasetData = data.map((row) => row.time);
    ylimit = 120;
  }

  if (chart) {
    chart.destroy();
  }

  const ctx = document.getElementById("gaming-time-chart").getContext("2d");

  // Create datasets array with bar chart
  const datasets = [
    {
      type: "bar",
      data: datasetData,
      borderWidth: 2,
      backgroundColor: yearlySummaryEnabled ? "rgba(135, 206, 250, 0.4)" : undefined,
      borderColor: yearlySummaryEnabled ? "rgba(135, 206, 250, 0.6)" : undefined,
      order: 2,
    },
  ];

  // Add trendline only for yearly view
  if (yearlySummaryEnabled) {
    datasets.push({
      type: "line",
      data: datasetData,
      borderColor: "red",
      borderWidth: 2,
      pointRadius: 0,
      fill: false,
      tension: 0.1,
      order: 1,
    });
  }

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
          beginAtZero: true,
          suggestedMax: ylimit,
          type: "log2",
          title: chartTitleConfig("PlayTime (Hours)", 15),
          ticks: {
            color: '#000'
          }
        },
        // Alignment Hack: Add an identical y scale on right side, to center the graph on page.
        // Then hide the right side scale by setting label color identical to background.
        yRight: {
          title: chartTitleConfig("PlayTime (Hours)", 15, "#fff"),
          position: "right",
          grid: {
            display: false,
          },
          ticks: {
            color: "white",
          },
        },
        x: {
          title: chartTitleConfig(periodLabel, 15),
          ticks: {
            color: (tickObj) => {
              const date = new Date(
                selectedYear,
                selectedMonth,
                tickObj["tick"]["label"]
              );
              let day = date.getDay();
              if (day === 0 || day === 6) {
                return "red";
              }
              return "#000";
            },
          },
        },
      },
      plugins: {
        tooltip: {
          enabled: false,
        },
        legend: {
          display: false,
        },
        datalabels: {
          anchor: "end",
          align: "top",
          formatter: function (value) {
            var formattedValue = "";
            if (value != 0) {
              formattedValue = value;
            }
            return formattedValue;
          },
          color: "#000000",
          font: {
            family: "monospace",
          },
        },
      }
    },
  });

  // Align total hours display with chart plot area center
  alignTotalHoursDisplay();
}

// Calendar functions
function initializeCalendar() {
  // Build availableMonths and availableYears sets from gamingData
  gamingData.forEach(item => {
    const date = new Date(item.date);
    const year = date.getFullYear();
    const month = date.getMonth();
    const monthStr = `${year}-${String(month + 1).padStart(2, '0')}`;
    availableMonths.add(monthStr);
    availableYears.add(year);
  });

  // Set initial calendar year to most recent year
  calendarYear = finalYear;

  updateYearDisplay();
  updateMonthGrid();
}

function updateYearDisplay() {
  const yearDisplayElement = document.getElementById('year-display');
  yearDisplayElement.textContent = calendarYear;

  // Visual indication of current mode
  if (viewMode === 'yearly') {
    yearDisplayElement.classList.add('yearly-mode');
  } else {
    yearDisplayElement.classList.remove('yearly-mode');
  }
}

function updateMonthGrid() {
  const monthButtons = document.querySelectorAll('.month-btn');

  monthButtons.forEach((btn, index) => {
    const monthStr = `${calendarYear}-${String(index + 1).padStart(2, '0')}`;
    const hasData = availableMonths.has(monthStr);

    btn.classList.toggle('has-data', hasData);
    btn.classList.toggle('selected',
      viewMode === 'monthly' && index === selectedMonth && calendarYear === selectedYear
    );
    btn.disabled = !hasData;

    // Remove existing onclick handlers
    btn.onclick = null;

    if (hasData) {
      btn.onclick = () => {
        if (viewMode === 'monthly') {
          selectedYear = calendarYear;
          selectedMonth = index;
          updateChart(selectedYear, selectedMonth, false);
          updatePeriodDisplayWithMonth(selectedYear, selectedMonth);
          updateMonthGrid(); // Refresh selection
        }
      };
    }
  });
}

function setupYearNavigation() {
  document.getElementById('prev-year-button').addEventListener('click', () => {
    if (calendarYear > firstYear) {
      calendarYear--;
      updateYearDisplay();
      updateMonthGrid();

      // If in yearly view, also update chart
      if (viewMode === 'yearly') {
        selectedYear = calendarYear;
        updateChart(selectedYear, selectedMonth, true);
        updatePeriodDisplayWithYear(selectedYear);
      }
    }
  });

  document.getElementById('next-year-button').addEventListener('click', () => {
    if (calendarYear < finalYear) {
      calendarYear++;
      updateYearDisplay();
      updateMonthGrid();

      // If in yearly view, also update chart
      if (viewMode === 'yearly') {
        selectedYear = calendarYear;
        updateChart(selectedYear, selectedMonth, true);
        updatePeriodDisplayWithYear(selectedYear);
      }
    }
  });
}

function setupYearToggle() {
  document.getElementById('year-display').addEventListener('click', () => {
    toggleViewMode();
  });
}

function toggleViewMode() {
  if (viewMode === 'monthly') {
    // Switch to yearly view
    viewMode = 'yearly';
    periodLabel = 'Month of Year';

    // Disable month selection in yearly view
    document.querySelectorAll('.month-btn').forEach(btn => {
      btn.style.pointerEvents = 'none';
      btn.style.opacity = '0.5';
    });

    selectedYear = calendarYear;
    updateChart(calendarYear, selectedMonth, true);
    updatePeriodDisplayWithYear(calendarYear);
    updateYearDisplay(); // Update visual state
    updateMonthGrid();

  } else {
    // Switch to monthly view
    viewMode = 'monthly';
    periodLabel = 'Day of Month';

    // Enable month selection in monthly view
    document.querySelectorAll('.month-btn').forEach(btn => {
      btn.style.pointerEvents = 'auto';
      btn.style.opacity = '1';
    });

    updateChart(selectedYear, selectedMonth, false);
    updatePeriodDisplayWithMonth(selectedYear, selectedMonth);
    updateYearDisplay(); // Update visual state
    updateMonthGrid();
  }
}

// OBSOLETE: Removed in favor of calendar month selection
function switchToNextMonth() {
  if (selectedMonth === finalMonth && selectedYear === finalYear) {
    updateWarnMessage("No More Data");
    return;
  }

  if (selectedMonth === 11) {
    if (selectedYear != finalYear) {
      selectedYear = selectedYear + 1;
      selectedMonth = 0;
    }
  } else {
    selectedMonth = selectedMonth + 1;
  }
  updateChart(selectedYear, selectedMonth);
  updatePeriodDisplayWithMonth(selectedYear, selectedMonth);
}

function switchToPrevMonth() {
  if (selectedMonth === firstMonth && selectedYear === firstYear) {
    updateWarnMessage("No More Data");
    return;
  }

  if (selectedMonth === 0) {
    if (selectedYear != firstYear) {
      selectedYear = selectedYear - 1;
      selectedMonth = 11;
    }
  } else {
    selectedMonth = selectedMonth - 1;
  }
  updateChart(selectedYear, selectedMonth);
  updatePeriodDisplayWithMonth(selectedYear, selectedMonth);
}

function switchToNextYear() {
  if (selectedYear === finalYear) {
    updateWarnMessage("No More Data");
    return;
  } else {
    selectedYear = selectedYear + 1;
  }
  updateChart(selectedYear, selectedMonth, true);
  updatePeriodDisplayWithYear(selectedYear);
}

function switchToPrevYear() {
  if (selectedYear === firstYear) {
    updateWarnMessage("No More Data");
    return;
  } else {
    selectedYear = selectedYear - 1;
  }
  updateChart(selectedYear, selectedMonth, true);
  updatePeriodDisplayWithYear(selectedYear);
}

function bindButtonsToMonths() {
  document
    .getElementById("prev-button")
    .addEventListener("click", () => switchToPrevMonth());
  document
    .getElementById("next-button")
    .addEventListener("click", () => switchToNextMonth());
}

function toggleSummaryPeriod() {
  document
    .getElementById("prev-button")
    .replaceWith(document.getElementById("prev-button").cloneNode(true));
  document
    .getElementById("next-button")
    .replaceWith(document.getElementById("next-button").cloneNode(true));

  if (summaryPeriod === "monthly") {
    document
      .getElementById("prev-button")
      .addEventListener("click", () => switchToPrevYear());
    document
      .getElementById("next-button")
      .addEventListener("click", () => switchToNextYear());

    summaryPeriod = "yearly";
    periodLabel = "Month of Year";
    selectedYear = finalYear;
    selectedMonth = finalMonth;
    document.getElementById("period-button").innerText = "Monthly Summary";

    updateChart(selectedYear, selectedMonth, true);
    updatePeriodDisplayWithYear(selectedYear);
  } else {
    bindButtonsToMonths();

    summaryPeriod = "monthly";
    periodLabel = "Day of Month";
    selectedYear = finalYear;
    selectedMonth = finalMonth;
    document.getElementById("period-button").innerText = "Yearly Summary";

    updateChart(selectedYear, selectedMonth);
    updatePeriodDisplayWithMonth(selectedYear, selectedMonth);
  }
}

function loadDataFromTable() {
  gamingData = buildGamingData("date", "time");

  // Initialize date ranges
  const firstDate = new Date(gamingData[0].date);
  const lastDate = new Date(gamingData[gamingData.length - 1].date);
  firstYear = parseInt(firstDate.getFullYear());
  firstMonth = parseInt(firstDate.getMonth());
  finalYear = parseInt(lastDate.getFullYear());
  finalMonth = parseInt(lastDate.getMonth());

  selectedYear = finalYear;
  selectedMonth = finalMonth;

  // Initialize calendar
  initializeCalendar();

  updateChart(selectedYear, selectedMonth);
  updatePeriodDisplayWithMonth(selectedYear, selectedMonth);
}

// Setup calendar navigation and year toggle
setupYearNavigation();
setupYearToggle();

loadDataFromTable();
