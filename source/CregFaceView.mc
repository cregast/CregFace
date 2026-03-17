import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

class CregFaceView extends WatchUi.WatchFace {

    // Layout
    private var mCenterX = 0;
    private var mCenterY = 0;
    private var mRadius  = 0;

    // Dial asset
    private var mDialBitmap as Graphics.BitmapReference?;
    private var mDialBuffer as Graphics.BufferedBitmap?;

    // State
    private var mAwake = true;
    private var mPrevSecond = -1;

    // Tables
    private var mSin as Array<Float> = new Array<Float>[60];
    private var mCos as Array<Float> = new Array<Float>[60];
    private var mSecTable  as Array<Array<Number>> = new Array<Array<Number>>[60];
    private var mMinTable  as Array<Array<Number>> = new Array<Array<Number>>[60];
    private var mHourTable as Array<Array<Number>> = new Array<Array<Number>>[720];

    // Date cache
    private var mDayDateText      = "";
    private var mDayMonthDateText = "";
    private var mLastDateDay      = -1;

    private const WEEK_DAYS = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"];
    private const MONTH_NAMES = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];

    private const TWO_PI = 2.0 * Math.PI;

    private const HOUR_LEN = 0.50;
    private const MIN_LEN  = 0.78;
    private const SEC_LEN  = 0.88;
    private const SEC_TAIL = 0.15;

    // Height offsets for centering, from dc.getTextDimensions("A", Graphics.FONT_LARGE)[1] / 2;
    private const mFontLargeHeightOffset        = 32;
    private const mFontNumberMediumHeightOffset = 50;
    private const mFontXTinyHeightOffset        = 16;
    private var mDayDateTextDimensions as Array<Number> = [91, 32];

    private const mSecondHandWidth = 2;
    private const mMinuteHandWidth = 4;
    private const mHourHandWidth   = 6;

    //#region System Functions
    function initialize() {
        WatchFace.initialize();
        mDialBitmap = WatchUi.loadResource(Rez.Drawables.DialBackground) as Graphics.BitmapReference;
    }

    function onLayout(dc as Graphics.Dc) as Void {
        setDimensions(dc);
        buildTables();
        buildDialBuffer(dc);
        updateDateCache(dc);
    }

    function onEnterSleep() as Void {
        handleSleep(false);
    }

    function onExitSleep() as Void {
        handleSleep(true);
    }

    // Full redraw - triggered once per minute or on sleep/wake transition
    function onUpdate(dc as Graphics.Dc) as Void {
        updateDateCache(dc);
        clearScreen(dc);
        drawFace(dc, System.getClockTime());
        mPrevSecond = -1;
    }

    // Per-second partial update - only redraws the seconds hand
    function onPartialUpdate(dc as Graphics.Dc) as Void {
        if (!mAwake) {
            return;
        }
        redrawSecondHand(dc, System.getClockTime().sec);
    }

    //#endregion System Functions

    private function drawFace(dc as Graphics.Dc, t as System.ClockTime) as Void {
        if (mAwake) {
            drawActiveFace(dc, t);
        } else {
            drawIdleFace(dc, t);
        }
    }

    private function drawIdleFace(dc as Graphics.Dc, t as System.ClockTime) as Void {
        var hour12  = (t.hour % 12 == 0) ? 12 : t.hour % 12;
        var timeStr = hour12.toString() + ":" + t.min.format("%02d");

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            mCenterX,
            mCenterY - mFontNumberMediumHeightOffset,
            Graphics.FONT_NUMBER_MEDIUM,
            timeStr,
            Graphics.TEXT_JUSTIFY_CENTER
        );

        if (!mDayMonthDateText.equals("")) {
            dc.drawText(
                mCenterX,
                mCenterY + mFontNumberMediumHeightOffset - mFontXTinyHeightOffset,
                Graphics.FONT_XTINY,
                mDayMonthDateText,
                Graphics.TEXT_JUSTIFY_CENTER
            );
        }
    }

    private function drawActiveFace(dc as Graphics.Dc, t as System.ClockTime) as Void {
        // Draw analog dial with tick marks and hour numbers from buffer/bitmap
        if (mDialBuffer != null) {
            dc.drawBitmap(0, 0, mDialBuffer as Graphics.BufferedBitmap);
        } else if (mDialBitmap != null) {
            dc.drawBitmap(0, 0, mDialBitmap as Graphics.BitmapReference);
        }

        drawComplications(dc, t);
        redrawHands(dc, t.hour, t.min);
        redrawSecondHand(dc, t.sec);

        mPrevSecond = t.sec;
    }

    private function redrawSecondHand(dc as Graphics.Dc, sec as Number) {
        // Erase previous second hand
        if (mPrevSecond >= 0) {
            var prev = mSecTable[mPrevSecond];
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            dc.setPenWidth(mSecondHandWidth);
            dc.drawLine(prev[2], prev[3], prev[0], prev[1]);
        }

        // Draw new second hand
        var pos = mSecTable[sec];
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(mSecondHandWidth);
        dc.drawLine(pos[2], pos[3], pos[0], pos[1]);

        // Draw center boss on top
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(mCenterX, mCenterY, 6);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(mCenterX, mCenterY, 4);

        mPrevSecond = sec;
    }

    private function redrawHands(dc as Graphics.Dc, hour as Number, minute as Number) as Void {
        var minP  = mMinTable[minute];
        var hourP = mHourTable[(hour % 12) * 60 + minute];

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);

        dc.setPenWidth(mHourHandWidth);
        dc.drawLine(mCenterX, mCenterY, hourP[0], hourP[1]);

        dc.setPenWidth(mMinuteHandWidth);
        dc.drawLine(mCenterX, mCenterY, minP[0], minP[1]);
    }

    private function drawComplications(dc as Graphics.Dc, t as System.ClockTime) as Void {
        // 12 o'clock: Digital time
        var hour12  = (t.hour % 12 == 0) ? 12 : t.hour % 12;
        var timeStr = hour12.toString() + ":" + t.min.format("%02d");

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            mCenterX,
            mCenterY - (mRadius * 0.37) - mFontLargeHeightOffset,
            Graphics.FONT_LARGE,
            timeStr,
            Graphics.TEXT_JUSTIFY_CENTER
        );

        // 3 o'clock: Day + date
        if (mDayDateText != "") {
            var dateX = mCenterX + (mRadius * 0.40);
            var dateY = mCenterY - mFontXTinyHeightOffset;
            var xPad  = 8;
            var yPad  = 0;

            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
            dc.fillRectangle(
                dateX - mDayDateTextDimensions[0] / 2 - xPad,
                dateY - yPad,
                mDayDateTextDimensions[0] + 2 * xPad,
                mDayDateTextDimensions[1] + 2 * yPad
            );

            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                dateX,
                dateY,
                Graphics.FONT_XTINY,
                mDayDateText,
                Graphics.TEXT_JUSTIFY_CENTER
            );
        }

        // 6 o'clock: Steps
        var steps     = ActivityMonitor.getInfo().steps;
        var stepsText = (steps == null) ? "--" : steps.toString();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            mCenterX,
            mCenterY + (mRadius * 0.50) - mFontXTinyHeightOffset,
            Graphics.FONT_XTINY,
            stepsText,
            Graphics.TEXT_JUSTIFY_CENTER
        );

        // 6 o'clock: Notification dot
        if (System.getDeviceSettings().notificationCount > 0) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(mCenterX, mCenterY + (mRadius * 0.38), 5);
        }

        // 9 o'clock: Battery
        var batt = System.getSystemStats().battery;

        dc.setColor((batt <= 15.0 ? Graphics.COLOR_RED : Graphics.COLOR_WHITE), Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            mCenterX - (mRadius * 0.50),
            mCenterY - mFontXTinyHeightOffset,
            Graphics.FONT_XTINY,
            batt.format("%d") + "%",
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    // #region Setup helpers
    private function setDimensions(dc as Graphics.Dc) as Void {
        mCenterX = dc.getWidth()  / 2;
        mCenterY = dc.getHeight() / 2;
        mRadius  = (mCenterX < mCenterY ? mCenterX : mCenterY) - 10;
    }

    // Render the static dial bitmap once into an off-screen BufferedBitmap.
    private function buildDialBuffer(dc as Graphics.Dc) as Void {
        if (mDialBitmap == null) {
            return;
        }

        var opts = {
            :width  => dc.getWidth(),
            :height => dc.getHeight()
        };

        try {
            var bufRef = Graphics.createBufferedBitmap(opts);
            var buf    = bufRef.get() as Graphics.BufferedBitmap;
            var bdc    = buf.getDc();
            bdc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            bdc.clear();
            bdc.drawBitmap(0, 0, mDialBitmap as Graphics.BitmapReference);
            mDialBuffer = buf;
        } catch (ex instanceof Lang.Exception) {
            mDialBuffer = null;
        }
    }

    private function buildTables() as Void {
        buildTrigTables();
        buildSecondTable();
        buildMinuteTable();
        buildHourTable();
    }

    private function buildTrigTables() as Void {
        for (var i = 0; i < 60; i++) {
            var a   = (TWO_PI / 60.0) * i; // 2Pi/60 is step size

            mSin[i] = Math.sin(a);
            mCos[i] = Math.cos(a);
        }
    }

    private function buildSecondTable() as Void {
        for (var i = 0; i < 60; i++) {
            var s = mSin[i];
            var c = mCos[i];

            mSecTable[i] = [
                (mCenterX + mRadius * SEC_LEN  * s),
                (mCenterY - mRadius * SEC_LEN  * c),
                (mCenterX - mRadius * SEC_TAIL * s),
                (mCenterY + mRadius * SEC_TAIL * c)
            ];
        }
    }

    private function buildMinuteTable() as Void {
        for (var i = 0; i < 60; i++) {
            var s = mSin[i];
            var c = mCos[i];

            mMinTable[i] = [
                (mCenterX + mRadius * MIN_LEN * s),
                (mCenterY - mRadius * MIN_LEN * c)
            ];
        }
    }

    private function buildHourTable() as Void {
        for (var h = 0; h < 12; h++) {
            for (var m = 0; m < 60; m++) {
                var angleIndex = (h * 5 + m / 12);
                var s = mSin[angleIndex];
                var c = mCos[angleIndex];

                mHourTable[h * 60 + m] = [
                    (mCenterX + mRadius * HOUR_LEN * s),
                    (mCenterY - mRadius * HOUR_LEN * c)
                ];
            }
        }
    }
    // #endregion Setup helpers

    private function updateDateCache(dc as Graphics.Dc) as Void {
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);

        if (mLastDateDay == info.day) {
            return;
        }

        var dow = WEEK_DAYS[info.day_of_week - 1];
        var mon = MONTH_NAMES[info.month - 1];

        mDayDateText           = dow + " " + info.day.toString();
        mDayDateTextDimensions = dc.getTextDimensions(mDayDateText, Graphics.FONT_XTINY);
        mDayMonthDateText      = dow + ", " + mon + " " + info.day.toString();
        mLastDateDay           = info.day;
    }

    private function handleSleep(mAwakeState as Boolean) {
        mAwake      = mAwakeState;
        mPrevSecond = -1;
        WatchUi.requestUpdate();
    }

    private function clearScreen(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
    }
}