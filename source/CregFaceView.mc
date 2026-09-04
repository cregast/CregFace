import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

class CregFaceView extends WatchUi.WatchFace {
    // Layout
    private var mCenterX as Number = 0;
    private var mCenterY as Number = 0;
    private var mRadius as Number  = 0;

    // Pre-calculated hand pixel lengths
    private var mHourLenPx as Float = 0.0;
    private var mMinLenPx as Float  = 0.0;
    private var mSecLenPx as Float  = 0.0;
    private var mSecTailPx as Float = 0.0;

    // Dial asset
    private var mDialBitmap as Graphics.BitmapReference?;

    // State & Caching
    private var mIsAwake as Boolean       = true;
    private var mLastMin as Number        = -1;
    private var mLastHour as Number       = -1;
    private var mLastDateDay as Number    = -1;
    private var mLastSteps as Number      = -1;
    private var mLastBatt as Number       = -1;
    private var mLastNotifCount as Number = -1;

    // Pre-formatted cached strings
    private var mActiveTimeStr as String    = "";
    private var mIdleTimeStr as String      = "";
    private var mStepsText as String        = "--";
    private var mBattText as String         = "";
    private var mDayDateText as String      = "";
    private var mDayMonthDateText as String = "";

    // Pre-calculated date box geometry
    private var mDateRectWidth as Number  = 0;
    private var mDateRectHeight as Number = 0;

    // Lookup tables
    private var mSin as Array<Float> = new Array<Float>[60];
    private var mCos as Array<Float> = new Array<Float>[60];

    private const WEEK_DAYS   = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"];
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

    private const mSecondHandWidth = 2;
    private const mMinuteHandWidth = 4;
    private const mHourHandWidth   = 6;

    function initialize() {
        WatchFace.initialize();
        mDialBitmap = WatchUi.loadResource(Rez.Drawables.DialBackground) as Graphics.BitmapReference;
    }

    function onLayout(dc as Graphics.Dc) as Void {
        setDimensions(dc);
        buildTrigTables();
        updateDateCache(dc, Gregorian.info(Time.now(), Time.FORMAT_SHORT));
        updateSystemComplications();
    }

    function onEnterSleep() as Void {
        handleSleep(false);
    }

    function onExitSleep() as Void {
        handleSleep(true);
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var clockTime = System.getClockTime();
        if (mIsAwake) {
            drawActiveFace(dc, clockTime);
        } else {
            drawIdleFace(dc, clockTime);
        }
    }

    private function drawIdleFace(dc as Graphics.Dc, t as System.ClockTime) as Void {
        updateTimeStrings(t);

        // Large digital time
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            mCenterX,
            mCenterY - mFontNumberMediumHeightOffset,
            Graphics.FONT_NUMBER_MEDIUM,
            mIdleTimeStr,
            Graphics.TEXT_JUSTIFY_CENTER
        );

        // Date
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
        if (mDialBitmap != null) {
            dc.drawBitmap(0, 0, mDialBitmap as Graphics.BitmapReference);
        }

        drawComplications(dc, t);
        drawHands(dc, t.hour, t.min);
        drawSecondHand(dc, t.sec);
    }

    private function drawSecondHand(dc as Graphics.Dc, sec as Number) as Void {
        var s = mSin[sec];
        var c = mCos[sec];

        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(mSecondHandWidth);
        dc.drawLine(
            (mCenterX - mSecTailPx * s),
            (mCenterY + mSecTailPx * c),
            (mCenterX + mSecLenPx * s),
            (mCenterY - mSecLenPx * c)
        );

        // Center boss
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(mCenterX, mCenterY, 6);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(mCenterX, mCenterY, 4);
    }

    private function drawHands(dc as Graphics.Dc, hour as Number, minute as Number) as Void {
        var minS = mSin[minute];
        var minC = mCos[minute];

        var hourAngleIndex = ((hour % 12) * 5) + (minute / 12);
        var hourS = mSin[hourAngleIndex];
        var hourC = mCos[hourAngleIndex];

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);

        // Hour hand
        dc.setPenWidth(mHourHandWidth);
        dc.drawLine(
            mCenterX,
            mCenterY,
            (mCenterX + mHourLenPx * hourS),
            (mCenterY - mHourLenPx * hourC)
        );

        // Minute hand
        dc.setPenWidth(mMinuteHandWidth);
        dc.drawLine(
            mCenterX,
            mCenterY,
            (mCenterX + mMinLenPx * minS),
            (mCenterY - mMinLenPx * minC)
        );
    }

    private function drawComplications(dc as Graphics.Dc, t as System.ClockTime) as Void {
        updateTimeStrings(t);

        // Update slower changing system stats once per minute
        if (mLastMin != t.min) {
            updateSystemComplications();
        }

        // 12 o'clock: Digital time
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            mCenterX,
            mCenterY - (mRadius * 0.37) - mFontLargeHeightOffset,
            Graphics.FONT_LARGE,
            mActiveTimeStr,
            Graphics.TEXT_JUSTIFY_CENTER
        );

        // 3 o'clock: Day + date
        if (!mDayDateText.equals("")) {
            var dateX = mCenterX + (mRadius * 0.40);
            var dateY = mCenterY - mFontXTinyHeightOffset;

            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
            dc.fillRectangle(
                dateX - (mDateRectWidth / 2),
                dateY,
                mDateRectWidth,
                mDateRectHeight
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
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            mCenterX,
            mCenterY + (mRadius * 0.50) - mFontXTinyHeightOffset,
            Graphics.FONT_XTINY,
            mStepsText,
            Graphics.TEXT_JUSTIFY_CENTER
        );

        // 6 o'clock: Notification dot
        if (mLastNotifCount > 0) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(mCenterX, mCenterY + (mRadius * 0.38), 5);
        }

        // 9 o'clock: Battery
        dc.setColor((mLastBatt <= 15 ? Graphics.COLOR_RED : Graphics.COLOR_WHITE), Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            mCenterX - (mRadius * 0.50),
            mCenterY - mFontXTinyHeightOffset,
            Graphics.FONT_XTINY,
            mBattText,
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    private function updateTimeStrings(t as System.ClockTime) as Void {
        if (mLastMin == t.min && mLastHour == t.hour) {
            return;
        }

        var hour12 = (t.hour % 12 == 0) ? 12 : t.hour % 12;
        var minFormatted = t.min.format("%02d");

        mActiveTimeStr = hour12.toString() + ":" + minFormatted;
        mIdleTimeStr   = mActiveTimeStr;

        if (mLastHour != t.hour) {
            updateDateCache(null, Gregorian.info(Time.now(), Time.FORMAT_SHORT));
            mLastHour = t.hour;
        }

        mLastMin = t.min;
    }

    private function updateSystemComplications() as Void {
        // Steps
        var info = ActivityMonitor.getInfo();
        var steps = info.steps;
        if (steps != mLastSteps) {
            mStepsText = (steps == null) ? "--" : steps.toString();
            mLastSteps = steps;
        }

        // Battery level
        var battFloat = System.getSystemStats().battery;
        var battInt = (battFloat != null) ? battFloat.toNumber() : 0;
        if (battInt != mLastBatt) {
            mBattText = battInt.toString() + "%";
            mLastBatt = battInt;
        }

        // Notification count
        mLastNotifCount = System.getDeviceSettings().notificationCount;
    }

    private function updateDateCache(dc as Graphics.Dc?, info as Gregorian.Info) as Void {
        if (mLastDateDay == info.day && mDayDateText.length() > 0) {
            return;
        }

        var dow = WEEK_DAYS[info.day_of_week - 1];
        var mon = MONTH_NAMES[info.month - 1];

        mDayDateText       = dow + " " + info.day.toString();
        mDayMonthDateText  = dow + ", " + mon + " " + info.day.toString();
        mLastDateDay       = info.day;

        if (dc != null) {
            var dims = dc.getTextDimensions(mDayDateText, Graphics.FONT_XTINY);
            mDateRectWidth  = dims[0] + 16;
            mDateRectHeight = dims[1];
        }
    }

    private function setDimensions(dc as Graphics.Dc) as Void {
        mCenterX = dc.getWidth() / 2;
        mCenterY = dc.getHeight() / 2;
        mRadius  = (mCenterX < mCenterY ? mCenterX : mCenterY) - 10;

        mHourLenPx = mRadius * HOUR_LEN;
        mMinLenPx  = mRadius * MIN_LEN;
        mSecLenPx  = mRadius * SEC_LEN;
        mSecTailPx = mRadius * SEC_TAIL;
    }

    private function buildTrigTables() as Void {
        for (var i = 0; i < 60; i++) {
            var a = (TWO_PI / 60.0) * i;
            mSin[i] = Math.sin(a);
            mCos[i] = Math.cos(a);
        }
    }

    private function handleSleep(mIsAwakeState as Boolean) as Void {
        mIsAwake = mIsAwakeState;
        mLastMin = -1;
        WatchUi.requestUpdate();
    }
}