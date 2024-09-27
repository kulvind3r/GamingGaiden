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

function buildGamingData(key1, key2) {
    const table = document.getElementById('data-table');
    const rows = table.querySelectorAll('tbody tr');

    gamingData = Array.from(rows).map(row => {
        const value1 = row.cells[0].textContent;
        const value2 = parseFloat(row.cells[1].textContent);
        return { [key1]: value1, [key2]: value2 };
    });

    // Remove header row data
    gamingData.shift()

    return gamingData
}

// Dummy usage of variables to suppress not used false positive in codacy
// without ignoring the entire file.
chartTooltipConfig; chartDataLabelFontConfig; chartLegendConfig; chartTitleConfig; buildGamingData;