/*global ChartDataLabels, Chart, chartTitleConfig, gamingData, Log2Axis, getChartTextColor, getChartGridColor, getChartBackgroundColor*/
/*from chart.js, common.js and html templates*/

let chart;

Log2Axis.id = "log2";
Log2Axis.defaults = {};

Chart.register(Log2Axis);

function updateChart(gameCount, labelText, stepSize = 1) {
  let labels = [];
  let data = [];

  if (gameCount > gamingData.length) {
    gameCount = gamingData.length;
  }

  let i = 0;
  for (const game of gamingData) {
    if (i == gameCount) break;
    labels.push(game.name);
    data.push({ game: game.name, time: (game.time / 60).toFixed(1) });
    i++;
  }

  if (chart) {
    chart.destroy();
  }

  const ctx = document.getElementById("game-vs-time-chart").getContext("2d");

  chart = new Chart(ctx, {
    type: "bar",
    plugins: [ChartDataLabels],
    data: {
      labels: labels,
      datasets: [
        {
          label: labelText,
          data: data.map((row) => row.time),
          borderWidth: 2,
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      indexAxis: "y",
      scales: {
        y: {
          ticks: {
            autoSkip: false,
            color: getChartTextColor()
          },
          grid: {
            color: getChartGridColor()
          }
        },
        // Alignment Hack: Add an identical y scale on right side, to center the graph on page.
        // Then hide the right side scale by setting label color identical to background.
        yRight: {
          position: "right",
          grid: {
            display: false,
          },
          ticks: {
            color: getChartBackgroundColor(),
          },
        },
        x: {
          type: "log2",
          ticks: {
            stepSize: stepSize,
            color: getChartTextColor()
          },
          title: chartTitleConfig(labelText, 15),
          grid: {
            color: getChartGridColor()
          }
        },
      },
      elements: {
        bar: {
          borderWidth: 1,
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
          align: "right",
          color: getChartTextColor(),
          font: {
            family: "monospace",
          },
        },
      }
    },
  });
}

// Dummy usage of variables to suppress not used false positive in codacy
// without ignoring the entire file.
updateChart;
