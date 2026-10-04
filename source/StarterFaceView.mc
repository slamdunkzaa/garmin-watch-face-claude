import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.SensorHistory;
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
    private const BLUE = 0x00AAFF;
    private const YELLOW = 0xFFAA00;
    private const EMPTY_COLOR = 0x555555;

    // The screen is laid out on a grid of this many "pixels" across.
    private const GRID_SIZE = 97;
    private const STEP_SEGMENTS = 10;
    // The bars and stats take this many grid rows; the mascot and time
    // block above them is TOP_RATIO times as tall.
    private const BOTTOM_ROWS = 20;
    private const TOP_RATIO = 1.61;
    // Grid columns from the center of the screen to the center of the mascot.
    private const LOGO_OFFSET = 29;

    // Garmin's zone colors, zone 1 to zone 5.
    private const ZONE_COLORS as Array<Number> = [0xAAAAAA, 0x00AAFF, 0x55FF55, 0xFFAA00, 0xFF5555];

    private const FRAME_MS = 250;
    private const BLINK_FRAMES = 12;
    // Body Battery at or above which the mascot bounces, and below which
    // it is sleepy.
    private const ENERGETIC_LEVEL = 70;
    private const TIRED_LEVEL = 30;

    // The mascot without its feet, 16 columns wide.
    private const MASCOT_COLS = 16;
    private const MASCOT as Array<Number> = [0x3FFC, 0x3FFC, 0x37EC, 0x37EC, 0xFFFF, 0xFFFF, 0x3FFC, 0x3FFC, 0x1428];
    // Feet standing still, then the two halves of the walk cycle.
    private const FEET as Array<Number> = [0x1428, 0x0408, 0x1020];

    private const HEART as Array<Number> = [0x36, 0x7F, 0x7F, 0x7F, 0x3E, 0x1C, 0x08];
    private const BOLT as Array<Number> = [0x0E, 0x1C, 0x38, 0x7E, 0x1C, 0x18, 0x10];
    private const STRESS as Array<Number> = [0x14, 0x36, 0x63, 0x00, 0x63, 0x36, 0x14];
    private const BATTERY as Array<Number> = [0x00, 0xFE, 0x83, 0x83, 0x83, 0xFE, 0x00];
    private const BATTERY_LEVELS = 5;

    private const DAYS as Array<String> = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
    private const MONTHS as Array<String> = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN",
        "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];

    private var _isSleeping as Boolean = false;
    private var _px as Number = 4;
    // Cell size of the Body Battery text, a little smaller than the date.
    private var _smallPx as Number = 3;
    private var _zones as Array<Number>?;
    private var _bodyBattery as Number?;
    private var _stress as Number?;
    // Minute of the hour the sensor history was read in, so it is read
    // once a minute rather than on every animation frame.
    private var _historyMin as Number = -1;
    private var _timer as Timer.Timer?;
    // Animation frame of the mascot; 0 while it stands still.
    private var _frame as Number = 0;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {
        _px = dc.getWidth() / GRID_SIZE;
        _smallPx = 3 * _px / 4;
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
        readSensorHistory();

        if (_isSleeping && needsBurnInProtection()) {
            drawAlwaysOn(dc);
            return;
        }

        var px = _px;
        var centerX = dc.getWidth() / 2;
        var activityInfo = ActivityMonitor.getInfo();
        var heartRate = getHeartRate();

        var topHeight = headerHeight();
        var top = 17 * px;
        var bottom = top + topHeight + 3 * px;

        drawHeader(dc, centerX, top, topHeight, Graphics.COLOR_WHITE, 0);
        drawStepBar(dc, centerX, bottom, activityInfo);
        drawZoneBar(dc, centerX, bottom + 6 * px, heartRate);
        drawStats(dc, centerX, bottom + 13 * px, heartRate);
        drawBodyBattery(dc, centerX - LOGO_OFFSET * px, top + topHeight - 7 * _smallPx);
    }

    // AMOLED always-on mode: mascot, time and date only, drawn dimmer and
    // with gaps between the pixels to stay under the 10% luminance limit,
    // and nudged every minute so the same pixels are not always lit.
    private function drawAlwaysOn(dc as Dc) as Void {
        var height = headerHeight();
        var offset = (System.getClockTime().min % 5 - 2) * _px;

        drawHeader(dc, dc.getWidth() / 2 - 2 * _px, (dc.getHeight() - height) / 2 + offset, height,
            Graphics.COLOR_LT_GRAY, 2);
    }

    private function headerHeight() as Number {
        return Math.round(BOTTOM_ROWS * _px * TOP_RATIO).toNumber();
    }

    // Mascot on the left, time over date on the right, with the mascot
    // standing just above the Body Battery text, which shares the date's
    // bottom edge. gap is the space left between
    // the pixels of the mascot and time.
    private function drawHeader(dc as Dc, centerX as Number, top as Number, height as Number,
            timeColor as ColorType, gap as Number) as Void {
        var px = _px;
        var textX = centerX - 13 * px;

        drawLogo(dc, centerX - LOGO_OFFSET * px, top + height - 7 * _smallPx - px, gap);

        dc.setColor(timeColor, Graphics.COLOR_TRANSPARENT);
        PixelFont.drawText(dc, textX, top, getTimeString(), 2 * px, 3 * px, gap);

        dc.setColor(ORANGE, Graphics.COLOR_TRANSPARENT);
        PixelFont.drawText(dc, textX, top + height - 7 * px, getDateString(), px, px, gap / 2);
    }

    // Draws the mascot centered on centerX with its feet on bottom. While
    // animating it walks on the spot and blinks now and then; its mood
    // follows Body Battery: it bounces when full and walks slowly with
    // heavy eyelids when low.
    private function drawLogo(dc as Dc, centerX as Number, bottom as Number, gap as Number) as Void {
        // Stretched tall like the time digits next to it.
        var cellWidth = 6 * _px / 4;
        var cellHeight = 8 * _px / 4;
        var x = centerX - MASCOT_COLS * cellWidth / 2;
        var y = bottom - (MASCOT.size() + 1) * cellHeight;
        var bodyBattery = _bodyBattery;
        var tired = bodyBattery != null && bodyBattery < TIRED_LEVEL;
        var energetic = bodyBattery != null && bodyBattery >= ENERGETIC_LEVEL;
        var step = tired ? _frame / 2 : _frame;
        var feet = _frame == 0 ? 0 : 1 + step % 2;
        var blink = _frame % BLINK_FRAMES == BLINK_FRAMES - 1;

        if (energetic && _frame % 2 == 1) {
            y -= cellHeight;
        }

        dc.setColor(ORANGE, Graphics.COLOR_TRANSPARENT);
        PixelFont.drawSprite(dc, x, y, MASCOT, MASCOT_COLS, cellWidth, cellHeight, gap);
        PixelFont.drawSprite(dc, x, y + MASCOT.size() * cellHeight, [FEET[feet]], MASCOT_COLS, cellWidth, cellHeight, gap);

        if (blink || tired) {
            // Close the top half of each eye, or all of it when a tired
            // mascot blinks.
            var lid = blink && tired ? 2 * cellHeight : cellHeight;
            dc.fillRectangle(x + 4 * cellWidth, y + 2 * cellHeight, cellWidth, lid);
            dc.fillRectangle(x + 11 * cellWidth, y + 2 * cellHeight, cellWidth, lid);
        }
    }

    // Heart rate, stress and battery side by side, centered on centerX.
    private function drawStats(dc as Dc, centerX as Number, y as Number, heartRate as Number?) as Void {
        var gap = 3 * _px;
        var stress = _stress;
        var battery = System.getSystemStats().battery;
        var heartRateText = heartRate != null ? heartRate.toString() : "--";
        var stressText = stress != null ? stress.toString() : "--";
        var batteryText = battery.format("%d") + "%";
        var heartRateWidth = statWidth(7, heartRateText, _px);
        var stressWidth = statWidth(7, stressText, _px);
        var x = centerX - (heartRateWidth + stressWidth + statWidth(8, batteryText, _px) + 2 * gap) / 2;

        drawStat(dc, x, y, HEART, 7, RED, heartRateText, _px);
        x += heartRateWidth + gap;
        drawStat(dc, x, y, STRESS, 7, YELLOW, stressText, _px);
        x += stressWidth + gap;
        drawBattery(dc, x, y, battery, batteryText);
    }

    // Body Battery under the mascot, centered on centerX.
    private function drawBodyBattery(dc as Dc, centerX as Number, y as Number) as Void {
        var bodyBattery = _bodyBattery;
        var text = bodyBattery != null ? bodyBattery.toString() : "--";

        var cell = _smallPx;

        drawStat(dc, centerX - statWidth(7, text, cell) / 2, y, BOLT, 7, BLUE, text, cell);
    }

    private function statWidth(iconCols as Number, value as String, cell as Number) as Number {
        return (iconCols + 2) * cell + PixelFont.textWidth(value, cell);
    }

    // Draws an icon followed by a value, with its left edge at x, in
    // blocks of cell.
    private function drawStat(dc as Dc, x as Number, y as Number, icon as Array<Number>, iconCols as Number,
            iconColor as ColorType, value as String, cell as Number) as Void {
        dc.setColor(iconColor, Graphics.COLOR_TRANSPARENT);
        PixelFont.drawSprite(dc, x, y, icon, iconCols, cell, cell, 0);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        PixelFont.drawText(dc, x + (iconCols + 2) * cell, y, value, cell, cell, 0);
    }

    private function drawBattery(dc as Dc, x as Number, y as Number, battery as Float, text as String) as Void {
        var px = _px;
        var level = Math.ceil(battery * BATTERY_LEVELS / 100).toNumber();

        drawStat(dc, x, y, BATTERY, 8, Graphics.COLOR_WHITE, text, px);
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

    private function readSensorHistory() as Void {
        var min = System.getClockTime().min;

        if (min == _historyMin || !(Toybox has :SensorHistory)) {
            return;
        }
        _historyMin = min;
        if (SensorHistory has :getBodyBatteryHistory) {
            _bodyBattery = latestSample(SensorHistory.getBodyBatteryHistory({:period => 1}));
        }
        if (SensorHistory has :getStressHistory) {
            _stress = latestSample(SensorHistory.getStressHistory({:period => 1}));
        }
    }

    private function latestSample(history as SensorHistory.SensorHistoryIterator) as Number? {
        var sample = history.next();

        if (sample != null) {
            var data = sample.data;
            if (data != null) {
                return data.toNumber();
            }
        }
        return null;
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
