import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.System;

// ---------------------------------------------------------------------------
// CregFaceDelegate
//
// Companion delegate for CregFaceView.
//
// Responsibilities:
//   • onPowerBudgetExceeded — fired if onPartialUpdate() consumed too much
//     CPU time. We log the info in debug builds; no action needed in release
//     because the system already suppressed that draw call. Repeated budget
//     overruns would indicate the clip region is too large or too many pixels
//     are being redrawn — investigate with View > Watch Face Diagnostics in
//     the simulator.
//
//   • Tap handling (optional) — reserved for future use.
// ---------------------------------------------------------------------------

class CregFaceDelegate extends WatchUi.WatchFaceDelegate {

    function initialize() {
        WatchFaceDelegate.initialize();
    }

    // Called when onPartialUpdate() consumed more than the device's per-second
    // power budget. The system already suppressed the draw for that tick; we
    // do nothing here beyond accepting the notification gracefully.
    function onPowerBudgetExceeded(powerInfo as WatchUi.WatchFacePowerInfo) as Void {
        // In a debug build you could log:
        //   System.println("Power budget exceeded: " + powerInfo.executionTimeAverage);
        // In release: intentionally empty. Over-budget ticks are automatically
        // skipped by the runtime; the watchface degrades gracefully to ~1Hz or
        // less rather than crashing.
    }
}
