module.exports = {
    skipFiles: ['lib/openzeppelin-contracts/'],
    configureYulOptimizer: true,
    solcOptimizerDetails: {
        yul: true,
        yulDetails: {
            stackAllocation: true,
            optimizerSteps: "u"
        }
    }
};