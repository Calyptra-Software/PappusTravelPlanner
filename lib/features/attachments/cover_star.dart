import 'package:flutter/material.dart';

/// The one colour that says "this is the trip's cover".
///
/// Amber, and defined once so the star in the gallery and the mark on the strip
/// cannot drift apart. Not the trip's accent — a user-chosen colour is
/// invisible against half the photographs it would be drawn on — and emphatically
/// not red, which this app reserves for "this is happening now".
const Color kCoverStarColor = Color(0xFFFFC107);
