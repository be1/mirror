/*
 * Copyright (C) 2020  Benoît Rouits
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * ubuntu-calculator-app is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
import QtQuick 2.7
import QtQml 2.2

Item {
    id: countTimer

    signal triggered
    property int seconds: 3

    function start() {
        seconds = 3
        timer.start()
    }

    function stop() {
        timer.stop()
    }

    Timer {
        id: timer

        interval: 1000
        repeat: true
        onTriggered: {
            countTimer.seconds--
            if (countTimer.seconds == 0) {
                running = false;
                countTimer.triggered()
            }
        }
    }
}

