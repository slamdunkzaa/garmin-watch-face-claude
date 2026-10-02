import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Timer;
import Toybox.UserProfile;
import Toybox.WatchUi;

class StarterFaceView extends WatchUi.WatchFace {

    private const ORANGE = 0xD97757;
    private const RED = 0xFF5555;
    private const GREEN = 0x55FF55;
    private const EMPTY_COLOR = 0x555555;

    // The screen is laid out on a grid of this many "pixels" across.
    private const GRID_SIZE = 97;
    private const STEP_SEGMENTS = 10;

    // Garmin's zone colors, zone 1 to zone 5.
    private const ZONE_COLORS as Array<Number> = [0xAAAAAA, 0x00AAFF, 0x55FF55, 0xFFAA00, 0xFF5555];

    private const FRAME_MS = 250;
    private const BLINK_FRAMES = 12;

    // The mascot without its feet, 16 columns wide.
    private const MASCOT_COLS = 16;
    private const MASCOT as Array<Number> = [0x3FFC, 0x3FFC, 0x37EC, 0x37EC, 0xFFFF, 0xFFFF, 0x3FFC, 0x3FFC, 0x1428];
    // Feet standing still, then the two halves of the walk cycle.
    private const FEET as Array<Number> = [0x1428, 0x0408, 0x1020];

    private const HEART as Array<Number> = [0x36, 0x7F, 0x7F, 0x7F, 0x3E, 0x1C, 0x08];
    private const BOOT as Array<Number> = [0x30, 0x30, 0x30, 0x38, 0x3E, 0x7F, 0x7F];
    private const BATTERY as Array<Number> = [0x00, 0xFE, 0x83, 0x83, 0x83, 0xFE, 0x00];
    private const BATTERY_LEVELS = 5;

    private const DAYS as Array<String> = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
    private const MONTHS as Array<String> = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN",
        "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];

    private var _isSleeping as Boolean = false;
    private var _px as Number = 4;
    private var _zones as Array<Number>?;
    private var _timer as Timer.Timer?;
    // Animation frame of the mascot; 0 while it stands still.
    private var _frame as Number = 0;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {
        _px = dc.getWidth() / GRID_SIZE;
    }

    function onShow() as Void {
        _zones = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_GENERIC);
    }

    function onHide() as Void {
        stopAnimation();
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        if (_isSleeping && needsBurnInProtection()) {
            drawAlwaysOn(dc);
            return;
        }

        var px = _px;
        var centerX = dc.getWidth() / 2;
        var activityInfo = ActivityMonitor.getInfo();
        var steps = activityInfo.steps;
        var heartRate = getHeartRate();

        drawLogo(dc, centerX, 6 * px);

        dc.setColor(ORANGE, Graphics.COLOR_TRANSPARENT);
        PixelFont.drawTextCentered(dc, centerX, 20 * px, getDateString(), px, px);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        PixelFont.drawTextCentered(dc, centerX, 31 * px, getTimeString(), 3 * px, 3 * px);

        drawZoneBar(dc, centerX, 56 * px, heartRate);
        drawStat(dc, centerX - 21 * px, 62 * px, HEART, 7, RED, heartRate != null ? heartRate.toString() : "--");
        drawBattery(dc, centerX + 21 * px, 62 * px);
        drawStepBar(dc, centerX, 73 * px, activityInfo);
        drawStat(dc, centerX, 79 * px, BOOT, 7, ORANGE, steps != null ? steps.toString() : "--");
    }

    // AMOLED always-on mode: keep few pixels lit and move them every
    // minute so no pixel stays on long enough to burn in.
    private function drawAlwaysOn(dc as Dc) as Void {
        var cell = 2 * _px;
        var offset = (System.getClockTime().min % 5 - 2) * 7;

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        PixelFont.drawTextCentered(dc, dc.getWidth() / 2 + offset, dc.getHeight() / 2 - 7 * cell / 2 + offset,
            getTimeString(), cell, cell - 2);
    }

    // Draws the mascot with its top edge at y. While animating it walks
    // on the spot and blinks now and then.
    private function drawLogo(dc as Dc, centerX as Number, y as Number) as Void {
        var px = _px;
        var x = centerX - MASCOT_COLS * px / 2;
        var feet = _frame == 0 ? 0 : 1 + _frame % 2;

        dc.setColor(ORANGE, Graphics.COLOR_TRANSPARENT);
        PixelFont.drawSprite(dc, x, y, MASCOT, MASCOT_COLS, px, px);
        PixelFont.drawSprite(dc, x, y + MASCOT.size() * px, [FEET[feet]], MASCOT_COLS, px, px);

        if (_frame % BLINK_FRAMES == BLINK_FRAMES - 1) {
            // Close the top half of each eye.
            dc.fillRectangle(x + 4 * px, y + 2 * px, px, px);
            dc.fillRectangle(x + 11 * px, y + 2 * px, px, px);
        }
    }

    // Draws an icon followed by a value, centered on centerX.
    // Returns the left edge of the icon.
    private function drawStat(dc as Dc, centerX as Number, y as Number, icon as Array<Number>, iconCols as Number,
            iconColor as ColorType, value as String) as Number {
        var px = _px;
        var x = centerX - ((iconCols + 2) * px + PixelFont.textWidth(value, px)) / 2;

        dc.setColor(iconColor, Graphics.COLOR_TRANSPARENT);
        PixelFont.drawSprite(dc, x, y, icon, iconCols, px, px);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        PixelFont.drawText(dc, x + (iconCols + 2) * px, y, value, px, px);
        return x;
    }

    private function drawBattery(dc as Dc, centerX as Number, y as Number) as Void {
        var px = _px;
        var battery = System.getSystemStats().battery;
        var x = drawStat(dc, centerX, y, BATTERY, 8, Graphics.COLOR_WHITE, battery.format("%d") + "%");
        var level = Math.ceil(battery * BATTERY_LEVELS / 100).toNumber();

        dc.setColor(level > 1 ? GREEN : RED, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x + px, y + 2 * px, level * px, 3 * px);
    }

    // One block per heart rate zone, lit up to the current zone.
    private function drawZoneBar(dc as Dc, centerX as Number, y as Number, heartRate as Number?) as Void {
        var px = _px;
        var zones = _zones;
        var zone = 0;

        if (heartRate != null && zones != null) {
            // zones holds the bottom of zone 1, then the top of each zone.
            for (var i = 0; i < ZONE_COLORS.size() && i < zones.size(); i++) {
                if (heartRate >= zones[i]) {
                    zone++;
                }
            }
        }

        var x = centerX - (ZONE_COLORS.size() * 12 - 1) * px / 2;
        for (var i = 0; i < ZONE_COLORS.size(); i++) {
            dc.setColor(i < zone ? ZONE_COLORS[i] : EMPTY_COLOR, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x + i * 12 * px, y, 11 * px, 3 * px);
        }
    }

    // Row of blocks that fills up as the daily step goal is reached.
    private function drawStepBar(dc as Dc, centerX as Number, y as Number, activityInfo as ActivityMonitor.Info) as Void {
        var px = _px;
        var steps = activityInfo.steps;
        var stepGoal = activityInfo.stepGoal;
        var filled = 0;

        if (steps != null && stepGoal != null && stepGoal > 0) {
            filled = steps * STEP_SEGMENTS / stepGoal;
        }

        var x = centerX - (STEP_SEGMENTS * 6 - 1) * px / 2;
        for (var i = 0; i < STEP_SEGMENTS; i++) {
            dc.setColor(i < filled ? ORANGE : EMPTY_COLOR, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x + i * 6 * px, y, 5 * px, 3 * px);
        }
    }

    private function getTimeString() as String {
        var clockTime = System.getClockTime();
        var hour = clockTime.hour;

        if (!System.getDeviceSettings().is24Hour) {
            hour = hour % 12;
            if (hour == 0) {
                hour = 12;
            }
        }
        return Lang.format("$1$:$2$", [hour, clockTime.min.format("%02d")]);
    }

    private function getDateString() as String {
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        return Lang.format("$1$ $2$ $3$", [DAYS[(info.day_of_week as Number) - 1], info.day, MONTHS[(info.month as Number) - 1]]);
    }

    private function getHeartRate() as Number? {
        var heartRate = null;
        var activityInfo = Activity.getActivityInfo();

        if (activityInfo != null) {
            heartRate = activityInfo.currentHeartRate;
        }
        if (heartRate == null) {
            var sample = ActivityMonitor.getHeartRateHistory(1, true).next();
            if (sample != null && sample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
                heartRate = sample.heartRate;
            }
        }
        return heartRate;
    }

    // Timers may only run while the watch face is awake.
    private function startAnimation() as Void {
        if (_timer == null) {
            _timer = new Timer.Timer();
        }
        (_timer as Timer.Timer).start(method(:onFrame), FRAME_MS, true);
    }

    private function stopAnimation() as Void {
        if (_timer != null) {
            (_timer as Timer.Timer).stop();
        }
        _frame = 0;
    }

    function onFrame() as Void {
        _frame++;
        WatchUi.requestUpdate();
    }

    private function needsBurnInProtection() as Boolean {
        var settings = System.getDeviceSettings();
        return (settings has :requiresBurnInProtection) && settings.requiresBurnInProtection;
    }

    function onEnterSleep() as Void {
        _isSleeping = true;
        stopAnimation();
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        _isSleeping = false;
        startAnimation();
        WatchUi.requestUpdate();
    }

}
