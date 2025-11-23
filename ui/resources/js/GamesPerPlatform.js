/*global ChartDataLabels, Chart, chartTooltipConfig, chartLegendConfig, chartDataLabelFontConfig, buildGamingData, getChartTextColor, getChartBackgroundColor*/
/*from chart.js, common.js*/
let gamingData = [];

$("table")[0].setAttribute("id", "data-table");

function updateChart() {
  const ctx = document
    .getElementById("games-per-platform-chart")
    .getContext("2d");

  new Chart(ctx, {
    type: "doughnut",
    plugins: [ChartDataLabels],
    data: {
      labels: gamingData.map((row) => row.name),
      datasets: [
        {
          data: gamingData.map((row) => row.count),
          borderWidth: 2,
          borderColor: getChartBackgroundColor(),
          backgroundColor: [
            "#ff6384",
            "#36a2eb",
            "#ff9f40",
            "#4e79a7",
            "#e91e63", 
            "#26a69a",
            "#7e57c2",
            "#4caf50",
            "#ff7043",
            "#5c6bc0",
            "#8e24aa",
            "#d84315",
            "#0288d1"
          ],
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        tooltip: chartTooltipConfig,
        legend: chartLegendConfig,
        datalabels: {
          color: getChartTextColor(),
          font: chartDataLabelFontConfig,
        },
      },
    },
  });
}

function loadDataFromTable() {
  gamingData = buildGamingData("name", "count");
  updateChart();
}

loadDataFromTable();
