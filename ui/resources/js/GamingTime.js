/*global ChartDataLabels, Chart, chartTitleConfig, buildGamingData, Log2Axis, getChartTextColor, getChartGridColor, getChartBackgroundColor*/
/*global formatMonthString, updateYearDisplay, setupYearNavigation, updateMonthGrid*/
/*from chart.js, common.js, calendar-controls.js*/

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

function updatePeriodDisplayWithMonth() {
  // Display is now handled by calendar selection highlighting
  // Show total hours in warn message area
  updateWarnMessage(parseInt(monthTotalTime) + " Hours Played");
}

function updatePeriodDisplayWithYear() {
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
  let ymin;

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
    ymin = 0.25;
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
    ymin = 1;
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
      borderColor: "rgb(255, 99, 132)",
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
          suggestedMin: ymin,
          type: "log2",
          title: chartTitleConfig("PlayTime (Hours)", 15),
          ticks: {
            color: getChartTextColor()
          },
          grid: {
            color: getChartGridColor()
          }
        },
        // Alignment Hack: Add an identical y scale on right side, to center the graph on page.
        // Then hide the right side scale by setting label color identical to background.
        yRight: {
          title: chartTitleConfig("PlayTime (Hours)", 15, getChartBackgroundColor()),
          position: "right",
          grid: {
            display: false,
          },
          ticks: {
            color: getChartBackgroundColor(),
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
              return getChartTextColor();
            },
          },
          grid: {
            color: getChartGridColor()
          }
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
          color: getChartTextColor(),
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
    const monthStr = formatMonthString(year, month);
    availableMonths.add(monthStr);
    availableYears.add(year);
  });

  // Set initial calendar year to most recent year
  calendarYear = finalYear;

  refreshYearDisplay();
  refreshMonthGrid();
}

function refreshYearDisplay() {
  updateYearDisplay(calendarYear, {
    yearDisplayCallback: (element) => {
      // Visual indication of current mode
      if (viewMode === 'yearly') {
        element.classList.add('yearly-mode');
      } else {
        element.classList.remove('yearly-mode');
      }
    }
  });
}

function refreshMonthGrid() {
  updateMonthGrid({
    calendarYear: calendarYear,
    availableMonths: availableMonths,
    isMonthSelected: (monthIndex) => {
      return viewMode === 'monthly' && monthIndex === selectedMonth && calendarYear === selectedYear;
    },
    onMonthClick: (monthIndex) => {
      if (viewMode === 'monthly') {
        selectedYear = calendarYear;
        selectedMonth = monthIndex;
        updateChart(selectedYear, selectedMonth, false);
        updatePeriodDisplayWithMonth();
        refreshMonthGrid(); // Refresh selection
      }
    },
    disableInteraction: viewMode === 'yearly'
  });
}

function initYearNavigation() {
  setupYearNavigation({
    firstYear: firstYear,
    finalYear: finalYear,
    getCalendarYear: () => calendarYear,
    setCalendarYear: (year) => { calendarYear = year; },
    onYearChange: () => {
      refreshYearDisplay();
      refreshMonthGrid();

      // If in yearly view, also update chart
      if (viewMode === 'yearly') {
        selectedYear = calendarYear;
        updateChart(selectedYear, selectedMonth, true);
        updatePeriodDisplayWithYear();
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

    selectedYear = calendarYear;
    updateChart(calendarYear, selectedMonth, true);
    updatePeriodDisplayWithYear();
    refreshYearDisplay(); // Update visual state
    refreshMonthGrid();

  } else {
    // Switch to monthly view
    viewMode = 'monthly';
    periodLabel = 'Day of Month';

    updateChart(selectedYear, selectedMonth, false);
    updatePeriodDisplayWithMonth();
    refreshYearDisplay(); // Update visual state
    refreshMonthGrid();
  }
}

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
  updatePeriodDisplayWithMonth();
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
  updatePeriodDisplayWithMonth();
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

  // Setup calendar navigation and year toggle (after data is loaded)
  initYearNavigation();
  setupYearToggle();

  updateChart(selectedYear, selectedMonth);
  updatePeriodDisplayWithMonth();
}

loadDataFromTable();
