/*global Chart, chartTitleConfig*/
/*from chart.js, common.js*/

let gamingData = [];
let finishedCount = 0;
let inProgressCount = 0;
let holdCount = 0;
let foreverCount = 0;
let droppedCount = 0;

$("table")[0].setAttribute("id", "data-table");

// Create custom log axis in base 2
class Log2Axis extends Chart.Scale {
  constructor(cfg) {
    super(cfg);
    this._startValue = undefined;
    this._valueRange = 0;
  }

  parse(raw, index) {
    const value = Chart.LinearScale.prototype.parse.apply(this, [raw, index]);
    return isFinite(value) && value > 0 ? value : null;
  }

  determineDataLimits() {
    const { min, max } = this.getMinMax(true);
    this.min = isFinite(min) ? Math.max(0, min) : null;
    this.max = isFinite(max) ? Math.max(0, max) : null;
  }

  buildTicks() {
    const ticks = [];

    let power = Math.floor(Math.log2(this.min || 1));
    let maxPower = Math.ceil(Math.log2(this.max || 2));
    while (power <= maxPower) {
      ticks.push({
        value: Math.pow(2, power),
      });
      power += 1;
    }

    this.min = ticks[0].value;
    this.max = ticks[ticks.length - 1].value;
    return ticks;
  }

  /**
   * @protected
   */
  configure() {
    const start = this.min;

    super.configure();

    this._startValue = Math.log2(start);
    this._valueRange = Math.log2(this.max) - Math.log2(start);
  }

  getPixelForValue(value) {
    if (value === undefined || value === 0) {
      value = this.min;
    }

    return this.getPixelForDecimal(
      value === this.min
        ? 0
        : (Math.log2(value) - this._startValue) / this._valueRange
    );
  }

  getValueForPixel(pixel) {
    const decimal = this.getDecimalForPixel(pixel);
    return Math.pow(2, this._startValue + decimal * this._valueRange);
  }
}

Log2Axis.id = "log2";
Log2Axis.defaults = {};

Chart.register(Log2Axis);

function updateChart() {
  const ctx = document
    .getElementById("session-vs-playtime-chart")
    .getContext("2d");

  new Chart(ctx, {
    type: "scatter",
    data: {
      labels: gamingData.map((row) => row.name),
      datasets: [
        {
          data: gamingData.map((row) => ({
            x: row.sessions,
            y: row.playtime,
            completed: row.completed,
            status: row.status
          })),
          borderWidth: 2,
          pointBackgroundColor: function (context) {
            var valueCompleted = context.raw.completed;
            if(valueCompleted == "FALSE") {
              return "#a6cbf5"
            }
            else {
              var valueStatus = context.raw.status;
              if(valueStatus == ""){
                return "#59eb8a"
              }
              if(valueStatus == "hold"){
                return "#f5c37d"
              }
              if(valueStatus == "forever"){
                return "#d0d3db"
              }
              if(valueStatus == "dropped"){
                return "#deb297"
              }
            }
          },
          pointBorderColor: function (context) {
            var valueCompleted = context.raw.completed;
            if(valueCompleted == "FALSE") {
              return "#1f9afe"
            }
            else {
              var valueStatus = context.raw.status;
              if(valueStatus == ""){
                return "#059b27"
              }
              if(valueStatus == "hold"){
                return "#d78f34"
              }
              if(valueStatus == "forever"){
                return "#94979c"
              }
              if(valueStatus == "dropped"){
                return "#662f13"
              }
            }
          },
        },
      ],
    },
    options: {
      scales: {
        y: {
          type: "log2",
          title: chartTitleConfig("PlayTime (Hours)"),
        },
        // Alignment Hack: Add an identical y scale on right side, to center the graph on page.
        // Then hide the right side scale by setting ticks and title color identical to background.
        yRight: {
          type: "log2",
          position: "right",
          grid: {
            display: false,
          },
          title: chartTitleConfig("PlayTime (Hours)", 0, "white"),
          ticks: {
            color: "white",
          },
        },
        x: {
          title: chartTitleConfig("Game Sessions", 15),
          ticks: {
            stepSize: 10,
          },
        },
      },
      elements: {
        point: {
          radius: 3.5,
          hoverRadius: 4.5
        }
      },
      responsive: true,
      plugins: {
        tooltip: {
          enabled: true,
          mode: "nearest",
          caretPadding: 7,
          displayColors: false,
          callbacks: {
            label: function (context) {
              let label =
                context.parsed.y +
                " hrs over " +
                context.parsed.x +
                " sessions";
              return label;
            },
          },
        },
        legend: {
          display: false,
        },
      },
      maintainAspectRatio: true,
    },
  });
}

function loadDataFromTable() {
  const table = document.getElementById("data-table");
  const rows = table.querySelectorAll("tbody tr");

  gamingData = Array.from(rows).map((row) => {
    const name = row.cells[0].textContent;
    const playtime = (parseFloat(row.cells[1].textContent) / 60).toFixed(1);
    const sessions = parseFloat(row.cells[2].textContent);
    const completed = row.cells[3].textContent;
    const status = row.cells[4].textContent;

    completed == "FALSE" ? inProgressCount++ : finishedCount++;
    if (status == "hold") { holdCount++ }
    if (status == "forever") { foreverCount++ }
    if (status == "dropped") { droppedCount++ }

    return { name, playtime, sessions, completed, status };
  });

  // Remove header row data, deduct one extra game added to finished count due to header row
  gamingData.shift();
  finishedCount--;

  let gameProgressMsg = (inProgressCount > 1) ? " Games In Progress" : " Game In Progress";
  let gameFinishedMsg = (finishedCount > 1) ? " Games Finished" : " Game Finished";
  let gameHoldMsg = (holdCount > 1) ? " Games on Hold" : " Game on Hold";
  let gameForeverMsg = (foreverCount > 1) ? " Forever Games" : " Forever Game";
  let gameDroppedMsg = (droppedCount > 1) ? " Dropped Games " : " Dropped Game";

  document.getElementById("progress-count").innerText =
    inProgressCount + gameProgressMsg;
  document.getElementById("finished-count").innerText =
    finishedCount + gameFinishedMsg;
  document.getElementById("hold-count").innerText =
    holdCount + gameHoldMsg;
  document.getElementById("forever-count").innerText =
    foreverCount + gameForeverMsg;
  document.getElementById("dropped-count").innerText =
    droppedCount + gameDroppedMsg;
  updateChart();
}

loadDataFromTable();
