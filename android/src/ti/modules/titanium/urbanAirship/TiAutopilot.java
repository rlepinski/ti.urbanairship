package ti.modules.titanium.urbanairship;

import android.util.Log;

import com.urbanairship.Autopilot;
import com.urbanairship.UAirship;

public class TiAutoPilot extends Autopilot {

    private static final String LCAT = "UrbanAirshipModule";

    @Override
    public void onAirshipReady(UAirship airship) {
        Log.i(LCAT, "Airship ready for configuration");
    }
}
