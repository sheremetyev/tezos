from tools import constants, utils

HASH = constants.DELPHI
DAEMON = constants.DELPHI_DAEMON
PARAMETERS = constants.DELPHI_PARAMETERS

PREV_HASH = constants.CARTHAGE
PREV_DAEMON = constants.CARTHAGE_DAEMON
PREV_PARAMETERS = constants.CARTHAGE_PARAMETERS


def activate(
    client, parameters=PARAMETERS, timestamp=None, activate_in_the_past=False
):
    utils.activate_protocol(
        client, HASH, parameters, timestamp, activate_in_the_past
    )
