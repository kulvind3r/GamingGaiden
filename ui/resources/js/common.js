/*global Chart*/
/*from chart.js*/

var chartTooltipConfig = {
  displayColors: false,
  yAlign: "top",
  caretPadding: 7,
  callbacks: {
    label: function () {
      return "";
    },
  },
};

var chartLegendConfig = {
  onClick: null,
  position: "bottom",
  labels: {
    boxWidth: 20,
    padding: 40,
    font: {
      size: 18,
      weight: "bold",
      family: "monospace",
    },
  },
};

var chartDataLabelFontConfig = {
  size: 18,
  weight: "bold",
  family: "monospace",
};

function chartTitleConfig(title, padding = 0, color = "#000") {
  return {
    display: true,
    padding: padding,
    color: color,
    text: title,
    font: {
      size: 18,
      family: "monospace",
    },
  };
}

function buildGamingData(
  key1,
  key2,
  tableId = "data-table",
  querySelectorTag = null
) {
  let table = document.getElementById(tableId);
  if (querySelectorTag != null) {
    table = document.getElementById(tableId).querySelector(querySelectorTag);
  }
  const rows = table.querySelectorAll("tbody tr");

  let gamingData = Array.from(rows).map((row) => {
    const value1 = row.cells[0].textContent;
    const value2 = parseFloat(row.cells[1].textContent);
    return { [key1]: value1, [key2]: value2 };
  });

  // Remove header row data
  gamingData.shift();

  return gamingData;
}

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
      value === this.min ? 0 : (Math.log2(value) - this._startValue) / this._valueRange
    );
  }

  getValueForPixel(pixel) {
    const decimal = this.getDecimalForPixel(pixel);
    return Math.pow(2, this._startValue + decimal * this._valueRange);
  }
}

// Dummy usage of variables to suppress not used false positive in codacy
// without ignoring the entire file.
chartTooltipConfig;
chartDataLabelFontConfig;
chartLegendConfig;
chartTitleConfig;
buildGamingData;
Log2Axis;
