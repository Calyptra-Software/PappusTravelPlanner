package com.baseflow.geolocator.location;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.baseflow.geolocator.errors.ErrorCallback;
import com.baseflow.geolocator.errors.ErrorCodes;

import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;

public class GeolocationManager
    implements io.flutter.plugin.common.PluginRegistry.ActivityResultListener {

    private static GeolocationManager geolocationManagerInstance = null;

  private final List<LocationClient> locationClients;

  private GeolocationManager() {
    this.locationClients = new CopyOnWriteArrayList<>();
  }

  public static synchronized GeolocationManager getInstance() {
      if (geolocationManagerInstance == null) {
          geolocationManagerInstance = new GeolocationManager();
      }

      return geolocationManagerInstance;
  }

  public void getLastKnownPosition(
      Context context,
      boolean forceLocationManager,
      PositionChangedCallback positionChangedCallback,
      ErrorCallback errorCallback) {

    LocationClient locationClient = createLocationClient(context, forceLocationManager, null);
    locationClient.getLastKnownPosition(positionChangedCallback, errorCallback);
  }

  public void isLocationServiceEnabled(
      @Nullable Context context, LocationServiceListener listener) {
    if (context == null) {
      listener.onLocationServiceError(ErrorCodes.locationServicesDisabled);
    }

    LocationClient locationClient = createLocationClient(context, false, null);
    locationClient.isLocationServiceEnabled(listener);
  }

  public void startPositionUpdates(
      @NonNull LocationClient locationClient,
      @Nullable Activity activity,
      @NonNull PositionChangedCallback positionChangedCallback,
      @NonNull ErrorCallback errorCallback) {

    this.locationClients.add(locationClient);
    locationClient.startPositionUpdates(activity, positionChangedCallback, errorCallback);
  }

  public void stopPositionUpdates(@NonNull LocationClient locationClient) {
    locationClients.remove(locationClient);
    locationClient.stopPositionUpdates();
  }

  // Vendored change: upstream picks FusedLocationClient (Google Play Services)
  // here whenever GoogleApiAvailability reports them present, and falls back to
  // LocationManagerClient otherwise. This copy has no Fused client, so the
  // fallback is the only path. `forceAndroidLocationManager` is kept in the
  // signature -- it is what the method channel passes -- but no longer selects
  // anything. See README.md beside this package for why.
  public LocationClient createLocationClient(
      Context context,
      boolean forceAndroidLocationManager,
      @Nullable LocationOptions locationOptions) {
    return new LocationManagerClient(context, locationOptions);
  }

  @Override
  public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
    for (LocationClient client : this.locationClients) {
      if (client.onActivityResult(requestCode, resultCode)) {
        return true;
      }
    }

    return false;
  }
}
