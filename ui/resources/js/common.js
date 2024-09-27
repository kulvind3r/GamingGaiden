/*global chartTitleConfig, chartTooltipConfig, chartLegendConfig, chartDataLabelFontConfig*/

var chartTooltipConfig = {
        displayColors: false,
        yAlign: 'top',
        caretPadding: 7,
        callbacks: {
            label: function () {
                return ''
            }
        }
    }

var chartLegendConfig = {
        onClick: null,
        position: 'bottom',
        labels: {
            boxWidth: 20,
            padding: 40,
            font: {
                size: 18,
                weight: 'bold',
                family: 'monospace'
            }
        }
    }

var chartDataLabelFontConfig = {
        size: 18,
        weight: 'bold',
        family: 'monospace'
    }

function chartTitleConfig(title, padding = 0, color="#000") {
    return {
        display: true,
        padding: padding,
        color: color,
        text: title,
        font: {
            size: 18,
            family: 'monospace'
        }
    }
}