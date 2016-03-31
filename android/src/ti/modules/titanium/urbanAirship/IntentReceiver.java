/**
 * Ti.Urbanairship Module
 * Copyright (c) 2010-2013 by Appcelerator, Inc. All Rights Reserved.
 * Please see the LICENSE included with this distribution for details.
 */
package ti.modules.titanium.urbanairship;

import java.util.HashMap;
import java.util.Set;

import android.content.Context;
import android.os.Bundle;
import android.util.Log;

import com.urbanairship.push.BaseIntentReceiver;
import com.urbanairship.push.PushMessage;

public class IntentReceiver extends BaseIntentReceiver {
    private static final String TAG = "UrbanAirshipModule_IntentReceiver";

    @Override
    protected void onChannelRegistrationSucceeded(Context context, String channelId) {
        Log.i(TAG, "Channel registration updated. Channel Id:" + channelId + ".");
        UrbanAirshipModule.handleRegistrationComplete(channelId, true);
    }

    @Override
    protected void onChannelRegistrationFailed(Context context) {
        Log.i(TAG, "Channel registration failed.");
        UrbanAirshipModule.handleRegistrationComplete(null, false);
    }

    private HashMap<String, Object> getPayloadFromPushMessage(PushMessage msg) {
        HashMap<String, Object> retval = new HashMap<String, Object>();
        Bundle pushBundle = msg.getPushBundle();
        Set<String> keys = pushBundle.keySet();

        for (String key : keys) {
            retval.put(key, pushBundle.get(key));
        }

        return retval;
    }

    @Override
    protected void onPushReceived(Context context, PushMessage message, int notificationId) {
        HashMap<String, Object> msg = getPayloadFromPushMessage(message);
        Log.i(TAG, "Received push notification. Alert: " + message.getAlert() + ". Notification ID: " + notificationId);
        UrbanAirshipModule.handleReceivedMessage(message.getAlert(), msg, false, true);
    }

    @Override
    protected void onBackgroundPushReceived(Context context, PushMessage message) {
        HashMap<String, Object> msg = getPayloadFromPushMessage(message);
        Log.i(TAG, "Received background push message: " + msg);
        UrbanAirshipModule.handleReceivedMessage(message.getAlert(), msg, false, false);
    }

    @Override
    protected boolean onNotificationOpened(Context context, PushMessage message, int notificationId) {
        HashMap<String, Object> msg = getPayloadFromPushMessage(message);
        Log.i(TAG, "User clicked notification. Alert: " + message.getAlert());

        UrbanAirshipModule.handleReceivedMessage(message.getAlert(), msg, true, true);
        // Return false to let UA handle launching the launch activity
        return true;
    }

    @Override
    protected boolean onNotificationActionOpened(Context context, PushMessage message, int notificationId, String buttonId, boolean isForeground) {
        Log.i(TAG, "User clicked notification button. Button ID: " + buttonId + " Alert: " + message.getAlert());

        // Return false to let UA handle launching the launch activity
        return false;
    }

    @Override
    protected void onNotificationDismissed(Context context, PushMessage message, int notificationId) {
        Log.i(TAG, "Notification dismissed. Alert: " + message.getAlert() + ". Notification ID: " + notificationId);
    }
}