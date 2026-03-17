import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Timer;
import Toybox.WatchUi;

class CregFaceView extends WatchUi.WatchFace {
    private var mAwake as Boolean                  = true;
    private var mTimer as Timer.Timer?             = null;
    private var mCenterX as Number                 = 0;
    private var mCenterY as Number                 = 0;
    private var mRadius as Number                  = 0;
    private var mDateDims as Array<Number>?        = null;
    private var mIdleDigitalDims as Array<Number>? = null;
    private var mDayDateText as String?            = null;  // Cache the date string
    private var mDayMonthDateText as String?       = null;  // Cache the date string
    private var mLastDateUpdate as Number?         = null;  // Store last date update (day of month)

    private const WEEK_DAYS   = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    private const MONTH_NAMES = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sept", "Oct", "Nov", "Dec"];

    function initialize() {
        WatchFace.initialize();
        updateDateText(); // Initialize date text
    }

    // Load resources and compute static values
    function onLayout(dc as Dc) as Void {
        mCenterX = dc.getWidth() / 2;
        mCenterY = dc.getHeight() / 2;
        mRadius  = (mCenterX < mCenterY ? mCenterX : mCenterY) - 10;

        // Cache text dimensions for complications
        mDateDims        = dc.getTextDimensions(mDayDateText, Graphics.FONT_XTINY);
        mIdleDigitalDims = dc.getTextDimensions("12:59", Graphics.FONT_NUMBER_MEDIUM);
    }

    // Helper function to update cached date text
    private function updateDateText() as Void {
        var time      = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var dayOfWeek = WEEK_DAYS[time.day_of_week - 1];
        var month     = MONTH_NAMES[time.month - 1];

        mDayDateText      = Lang.format("$1$ $2$", [dayOfWeek, time.day]);
        mDayMonthDateText = Lang.format("$1$, $2$ $3$", [dayOfWeek, month, time.day]);

        mLastDateUpdate   = time.day;
    }

    function onShow() as Void {
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        if (mAwake) {
            drawActiveFace(dc);
        } else {
            drawIdleFace(dc);
        }
    }

    function onHide() as Void {
    }

    function onExitSleep() as Void {
        mAwake = true;
        if (mTimer == null) {
            mTimer = new Timer.Timer();
            mTimer.start(method(:onTimer), 1000, true);
        }
        WatchUi.requestUpdate();
    }

    function onEnterSleep() as Void {
        mAwake = false;
        if (mTimer != null) {
            mTimer.stop();
            mTimer = null;
        }
        WatchUi.requestUpdate();
    }

    function onTimer() as Void {
        WatchUi.requestUpdate();
    }

    function drawIdleFace(dc as Dc) as Void {
        var time = Gregorian.info(Time.now(), Time.FORMAT_SHORT);

        // Check if date needs updating (only recalculate once per day)
        if (mLastDateUpdate == null || mLastDateUpdate != time.day) {
            updateDateText();
        }

        // Draw the time
        var hour12 = (time.hour % 12 == 0) ? 12 : time.hour % 12;
        var digitalText = Lang.format("$1$:$2$", [hour12.format("%d"), time.min.format("%02d")]);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        if (mIdleDigitalDims != null) {
            var digitalX = mCenterX ;
            var digitalY = mCenterY - (mDateDims != null ? mDateDims[1] / 2 : 0);
            dc.drawText(digitalX, digitalY,
                        Graphics.FONT_NUMBER_MEDIUM,
                        digitalText,
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // Draw the date
        if (mDayMonthDateText != null) {
            var dateX = mCenterX ;
            var dateY = mCenterY + (mIdleDigitalDims != null ? mIdleDigitalDims[1] / 2 : 0);
            dc.drawText(dateX, dateY,
                        Graphics.FONT_XTINY,
                        mDayMonthDateText,
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    function drawActiveFace(dc as Dc) as Void {
        // Draw static dial elements
        drawDial(dc);

        // Get current time for hands and digital time
        var t      = System.getClockTime();
        var hour   = t.hour % 12;
        var minute = t.min;
        var second = t.sec;

        // === DATE WIDGET at 3 o'clock ===
        var dateX    = mCenterX + mRadius * 0.4;
        var dateY    = mCenterY;
        var xPadding = 4;
        var yPadding = 4;

        if (mDateDims != null) {
            var rectX = dateX - mDateDims[0] / 2 - xPadding;
            var rectY = dateY - mDateDims[1] / 2 - yPadding / 2;
            var rectW = mDateDims[0] + 2 * xPadding;
            var rectH = mDateDims[1] + yPadding;

            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
            dc.fillRectangle(rectX, rectY, rectW, rectH);

            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.drawText(dateX, dateY,
                        Graphics.FONT_XTINY,
                        mDayDateText,
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // === STEPS at 6 o'clock ===
        var activityInfo = ActivityMonitor.getInfo();
        var steps        = activityInfo.steps;
        var stepsText    = Lang.format("$1$", [steps]);
        var stepsX       = mCenterX;
        var stepsY       = mCenterY + (mRadius * 0.55);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(stepsX, stepsY,
                    Graphics.FONT_XTINY,
                    stepsText,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // === BATTERY at 9 o'clock ===
        var battStats    = System.getSystemStats();
        var batteryLevel = battStats.battery;
        var battText     = Lang.format("$1$%", [batteryLevel.format("%d")]);
        var battX        = mCenterX - (mRadius * 0.52);
        var battY        = mCenterY;
        var battColor    = (batteryLevel <= 15) ? Graphics.COLOR_RED : Graphics.COLOR_WHITE;

        dc.setColor(battColor, Graphics.COLOR_BLACK);
        dc.drawText(battX, battY,
                    Graphics.FONT_XTINY,
                    battText,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // === DIGITAL TIME at 12 o'clock ===
        var hour12      = (t.hour % 12 == 0) ? 12 : t.hour % 12;
        var digitalText = Lang.format("$1$:$2$", [hour12.format("%d"), t.min.format("%02d")]);
        var digitalX    = mCenterX;
        var digitalY    = mCenterY - (mRadius * 0.39);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(digitalX, digitalY,
                    Graphics.FONT_LARGE,
                    digitalText,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Draw notification indicator if there are notifications
        var stats = System.getDeviceSettings();
        if (stats.notificationCount > 0) {
            var notifyX = mCenterX;
            var notifyY = mCenterY + (mRadius * 0.38);
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_BLACK);
            dc.fillCircle(notifyX, notifyY, 5);
        }

        // === Clock hands ===
        var minuteAngle = (minute / 60.0) * 2 * Math.PI;
        var hourAngle   = ((hour + minute / 60.0) / 12.0) * 2 * Math.PI;
        var secAngle    = (second / 60.0) * 2 * Math.PI;

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);

        // Hour hand
        var hourX = mCenterX + (mRadius * 0.5) * Math.sin(hourAngle);
        var hourY = mCenterY - (mRadius * 0.5) * Math.cos(hourAngle);
        dc.setPenWidth(5);
        dc.drawLine(mCenterX, mCenterY, hourX, hourY);

        // Minute hand
        var minX = mCenterX + (mRadius * 0.8) * Math.sin(minuteAngle);
        var minY = mCenterY - (mRadius * 0.8) * Math.cos(minuteAngle);
        dc.drawLine(mCenterX, mCenterY, minX, minY);

        // Seconds hand
        var secX = mCenterX + (mRadius * 0.9) * Math.sin(secAngle);
        var secY = mCenterY - (mRadius * 0.9) * Math.cos(secAngle);
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_BLACK);
        dc.setPenWidth(1);
        dc.drawLine(mCenterX, mCenterY, secX, secY);
    }

    private function drawDial(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawCircle(mCenterX, mCenterY, mRadius);

        // Draw tick marks and hour labels
        for (var i = 0; i < 60; i++) {
            var angle  = 2 * Math.PI * i / 60.0;
            var innerR = (i % 5 == 0) ? mRadius - 15 : mRadius - 8;
            var outerX = mCenterX + mRadius * Math.sin(angle);
            var outerY = mCenterY - mRadius * Math.cos(angle);
            var innerX = mCenterX + innerR  * Math.sin(angle);
            var innerY = mCenterY - innerR  * Math.cos(angle);

            if (i % 5 == 0 || i % 5 == 1) {
                dc.setPenWidth((i % 5 == 0) ? 3 : 1);
            }
            dc.drawLine(innerX, innerY, outerX, outerY);

            if (i % 5 == 0) {
                var hour   = (i / 5 == 0) ? 12 : i / 5;
                var labelR = mRadius - 40;
                var lx     = mCenterX + labelR * Math.sin(angle);
                var ly     = mCenterY - labelR * Math.cos(angle);

                var font       = Graphics.FONT_TINY;
                var text       = hour.toString();
                var textHeight = dc.getFontHeight(font);

                ly -= textHeight / 2;
                dc.drawText(lx, ly, font, text, Graphics.TEXT_JUSTIFY_CENTER);
            }
        }
    }
}