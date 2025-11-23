/*global ChartDataLabels, Chart, chartTooltipConfig, chartLegendConfig, chartDataLabelFontConfig, buildGamingData, getChartTextColor, getChartBackgroundColor*/
/*from chart.js, common.js*/

let gamingData = [];

$("table")[0].setAttribute("id", "data-table");

function updateChart() {
  const ctx = document.getElementById("pc-vs-emulation-chart").getContext("2d");

  new Chart(ctx, {
    type: "pie",
    plugins: [ChartDataLabels],
    data: {
      labels: gamingData.map((row) => row.platform),
      datasets: [
        {
          data: gamingData.map((row) => (row.play_time / 60).toFixed(1)),
          borderWidth: 2,
          borderColor: getChartBackgroundColor(),
          backgroundColor: [
            "#1ea1e6",
            "#ff6481",
            "#3dbebe",
            "#ff9d4c",
            "#9669f8",
            "#ffca63",
            "#c7c9cd"
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
          formatter: function (value) {
            return value + " Hrs";
          },
          color: getChartTextColor(),
          font: chartDataLabelFontConfig,
        },
      },
    },
  });
}

function loadDataFromTable() {
  gamingData = buildGamingData("platform", "play_time");
  updateChart();
}

loadDataFromTable();
