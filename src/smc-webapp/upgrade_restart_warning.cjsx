# 3rd Party Libraries
{Alert} = require('react-bootstrap')

# Internal & React Libraries
{React} = require('./smc-react')

# Sibling Libraries

exports.UpgradeRestartWarning = ({style}) ->
    <Alert style={style}>
        WARNING: Adjusting upgrades may restart running projects, which would terminate computations.
    </Alert>