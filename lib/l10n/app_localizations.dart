import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_mr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('mr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'HITWARDHINI'**
  String get appTitle;

  /// No description provided for @findProperMatches.
  ///
  /// In en, this message translates to:
  /// **'Find Proper Matches'**
  String get findProperMatches;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @secureTrustedMatrimony.
  ///
  /// In en, this message translates to:
  /// **'Secure & Trusted Matrimony'**
  String get secureTrustedMatrimony;

  /// No description provided for @accountBlocked.
  ///
  /// In en, this message translates to:
  /// **'Account Blocked'**
  String get accountBlocked;

  /// No description provided for @accountBlockedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your account has been blocked by the administrator.'**
  String get accountBlockedMessage;

  /// No description provided for @reason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get reason;

  /// No description provided for @contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Please contact support for assistance.'**
  String get contactSupport;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get loginFailed;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @explore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get explore;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @interests.
  ///
  /// In en, this message translates to:
  /// **'Interests'**
  String get interests;

  /// No description provided for @viewProfile.
  ///
  /// In en, this message translates to:
  /// **'View Profile'**
  String get viewProfile;

  /// No description provided for @updatePhoto.
  ///
  /// In en, this message translates to:
  /// **'Update Photo'**
  String get updatePhoto;

  /// No description provided for @adminPanel.
  ///
  /// In en, this message translates to:
  /// **'Admin Panel'**
  String get adminPanel;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get goodEvening;

  /// No description provided for @yourActivity.
  ///
  /// In en, this message translates to:
  /// **'Your Activity'**
  String get yourActivity;

  /// No description provided for @sent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get sent;

  /// No description provided for @received.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get received;

  /// No description provided for @updatesSuccessStories.
  ///
  /// In en, this message translates to:
  /// **'Updates & Success Stories'**
  String get updatesSuccessStories;

  /// No description provided for @waitingInterest.
  ///
  /// In en, this message translates to:
  /// **'{count} new interest waiting!'**
  String waitingInterest(int count);

  /// No description provided for @waitingInterests.
  ///
  /// In en, this message translates to:
  /// **'{count} new interests waiting!'**
  String waitingInterests(int count);

  /// No description provided for @tapToViewRespond.
  ///
  /// In en, this message translates to:
  /// **'Tap to view and respond'**
  String get tapToViewRespond;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @yearsOld.
  ///
  /// In en, this message translates to:
  /// **'{age} years old'**
  String yearsOld(int age);

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name or city...'**
  String get searchHint;

  /// No description provided for @discoverMatches.
  ///
  /// In en, this message translates to:
  /// **'Discover Matches'**
  String get discoverMatches;

  /// No description provided for @profilesFound.
  ///
  /// In en, this message translates to:
  /// **'{count} profiles found'**
  String profilesFound(int count);

  /// No description provided for @profileFound.
  ///
  /// In en, this message translates to:
  /// **'{count} profile found'**
  String profileFound(int count);

  /// No description provided for @filtered.
  ///
  /// In en, this message translates to:
  /// **'Filtered'**
  String get filtered;

  /// No description provided for @noMatchesFound.
  ///
  /// In en, this message translates to:
  /// **'No matches found'**
  String get noMatchesFound;

  /// No description provided for @noProfilesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No profiles available'**
  String get noProfilesAvailable;

  /// No description provided for @tryAdjustingSearch.
  ///
  /// In en, this message translates to:
  /// **'Try adjusting your search criteria'**
  String get tryAdjustingSearch;

  /// No description provided for @checkBackLater.
  ///
  /// In en, this message translates to:
  /// **'Check back later for new profiles'**
  String get checkBackLater;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear Search'**
  String get clearSearch;

  /// No description provided for @sendInterest.
  ///
  /// In en, this message translates to:
  /// **'Send Interest'**
  String get sendInterest;

  /// No description provided for @interestSent.
  ///
  /// In en, this message translates to:
  /// **'Interest Sent'**
  String get interestSent;

  /// No description provided for @filterProfiles.
  ///
  /// In en, this message translates to:
  /// **'Filter Profiles'**
  String get filterProfiles;

  /// No description provided for @refineByAge.
  ///
  /// In en, this message translates to:
  /// **'Refine by age range'**
  String get refineByAge;

  /// No description provided for @ageRange.
  ///
  /// In en, this message translates to:
  /// **'Age Range'**
  String get ageRange;

  /// No description provided for @yrs.
  ///
  /// In en, this message translates to:
  /// **'{count} yrs'**
  String yrs(int count);

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @applyFilter.
  ///
  /// In en, this message translates to:
  /// **'Apply Filter'**
  String get applyFilter;

  /// No description provided for @noSavedProfiles.
  ///
  /// In en, this message translates to:
  /// **'No saved profiles yet'**
  String get noSavedProfiles;

  /// No description provided for @tapHeartToSave.
  ///
  /// In en, this message translates to:
  /// **'Tap the heart icon on profiles\nyou want to save for later'**
  String get tapHeartToSave;

  /// No description provided for @exploreProfiles.
  ///
  /// In en, this message translates to:
  /// **'Explore Profiles'**
  String get exploreProfiles;

  /// No description provided for @yourShortlist.
  ///
  /// In en, this message translates to:
  /// **'Your Shortlist'**
  String get yourShortlist;

  /// No description provided for @profilesSaved.
  ///
  /// In en, this message translates to:
  /// **'{count} profiles saved'**
  String profilesSaved(int count);

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'{count} profile saved'**
  String profileSaved(int count);

  /// No description provided for @noInterestsReceived.
  ///
  /// In en, this message translates to:
  /// **'No interests received yet'**
  String get noInterestsReceived;

  /// No description provided for @whenSomeoneSends.
  ///
  /// In en, this message translates to:
  /// **'When someone sends you an interest,\nit will appear here'**
  String get whenSomeoneSends;

  /// No description provided for @awaitingResponse.
  ///
  /// In en, this message translates to:
  /// **'Awaiting Response'**
  String get awaitingResponse;

  /// No description provided for @newCount.
  ///
  /// In en, this message translates to:
  /// **'{count} new'**
  String newCount(int count);

  /// No description provided for @previousInterests.
  ///
  /// In en, this message translates to:
  /// **'Previous Interests'**
  String get previousInterests;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @acceptInterest.
  ///
  /// In en, this message translates to:
  /// **'Accept Interest'**
  String get acceptInterest;

  /// No description provided for @noInterestsSent.
  ///
  /// In en, this message translates to:
  /// **'No interests sent yet'**
  String get noInterestsSent;

  /// No description provided for @sendInterestFromExplore.
  ///
  /// In en, this message translates to:
  /// **'Send interest to profiles you like\nfrom the Explore tab'**
  String get sendInterestFromExplore;

  /// No description provided for @matched.
  ///
  /// In en, this message translates to:
  /// **'Matched!'**
  String get matched;

  /// No description provided for @notMatched.
  ///
  /// In en, this message translates to:
  /// **'Not Matched'**
  String get notMatched;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @notInterested.
  ///
  /// In en, this message translates to:
  /// **'Not Interested'**
  String get notInterested;

  /// No description provided for @whatIsYourName.
  ///
  /// In en, this message translates to:
  /// **'What\'s your name?'**
  String get whatIsYourName;

  /// No description provided for @enterFullName.
  ///
  /// In en, this message translates to:
  /// **'Enter your full name (First & Last).'**
  String get enterFullName;

  /// No description provided for @whatIsYourGender.
  ///
  /// In en, this message translates to:
  /// **'What is your Gender?'**
  String get whatIsYourGender;

  /// No description provided for @findRelevantMatches.
  ///
  /// In en, this message translates to:
  /// **'To find relevant matches.'**
  String get findRelevantMatches;

  /// No description provided for @typeYourNumber.
  ///
  /// In en, this message translates to:
  /// **'Type your number?'**
  String get typeYourNumber;

  /// No description provided for @officialCommunication.
  ///
  /// In en, this message translates to:
  /// **'For official communication only.'**
  String get officialCommunication;

  /// No description provided for @whenWereYouBorn.
  ///
  /// In en, this message translates to:
  /// **'When were you born?'**
  String get whenWereYouBorn;

  /// No description provided for @findAgeGroupMatches.
  ///
  /// In en, this message translates to:
  /// **'To find matches in your age group.'**
  String get findAgeGroupMatches;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select Date'**
  String get selectDate;

  /// No description provided for @howTallAreYou.
  ///
  /// In en, this message translates to:
  /// **'How tall are you?'**
  String get howTallAreYou;

  /// No description provided for @enterHeightFeetInches.
  ///
  /// In en, this message translates to:
  /// **'Enter your height in Feet and Inches.'**
  String get enterHeightFeetInches;

  /// No description provided for @feet.
  ///
  /// In en, this message translates to:
  /// **'Feet'**
  String get feet;

  /// No description provided for @inches.
  ///
  /// In en, this message translates to:
  /// **'Inches'**
  String get inches;

  /// No description provided for @whatIsYourEducation.
  ///
  /// In en, this message translates to:
  /// **'What is your Education?'**
  String get whatIsYourEducation;

  /// No description provided for @degreesSpecializations.
  ///
  /// In en, this message translates to:
  /// **'Degrees, Specializations, etc.'**
  String get degreesSpecializations;

  /// No description provided for @whatDoYouDo.
  ///
  /// In en, this message translates to:
  /// **'What do you do?'**
  String get whatDoYouDo;

  /// No description provided for @professionJobTitle.
  ///
  /// In en, this message translates to:
  /// **'Your profession or job title.'**
  String get professionJobTitle;

  /// No description provided for @whereDoYouLive.
  ///
  /// In en, this message translates to:
  /// **'Where do you live?'**
  String get whereDoYouLive;

  /// No description provided for @currentCity.
  ///
  /// In en, this message translates to:
  /// **'Current city of residence.'**
  String get currentCity;

  /// No description provided for @addProfilePhoto.
  ///
  /// In en, this message translates to:
  /// **'Add a Profile Photo'**
  String get addProfilePhoto;

  /// No description provided for @photoInterestBoost.
  ///
  /// In en, this message translates to:
  /// **'Profiles with photos get 5x more interest.'**
  String get photoInterestBoost;

  /// No description provided for @uploadBiodata.
  ///
  /// In en, this message translates to:
  /// **'Upload Biodata'**
  String get uploadBiodata;

  /// No description provided for @familyBackground.
  ///
  /// In en, this message translates to:
  /// **'Detailed family background (PDF/Word).'**
  String get familyBackground;

  /// No description provided for @tapToUpload.
  ///
  /// In en, this message translates to:
  /// **'Tap to Upload Document'**
  String get tapToUpload;

  /// No description provided for @supportsFormats.
  ///
  /// In en, this message translates to:
  /// **'Supports PDF, DOC, DOCX'**
  String get supportsFormats;

  /// No description provided for @completeProfile.
  ///
  /// In en, this message translates to:
  /// **'Complete Profile'**
  String get completeProfile;

  /// No description provided for @continueText.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueText;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @profileGenerated.
  ///
  /// In en, this message translates to:
  /// **'Profile Generated!'**
  String get profileGenerated;

  /// No description provided for @profileLiveSearch.
  ///
  /// In en, this message translates to:
  /// **'Your profile is now live. You can start searching for matches immediately.'**
  String get profileLiveSearch;

  /// No description provided for @enterMatrimony.
  ///
  /// In en, this message translates to:
  /// **'Enter Matrimony'**
  String get enterMatrimony;

  /// No description provided for @errorSavingProfile.
  ///
  /// In en, this message translates to:
  /// **'Error saving profile'**
  String get errorSavingProfile;

  /// No description provided for @pleaseEnterFullName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid full name (min 3 chars)'**
  String get pleaseEnterFullName;

  /// No description provided for @pleaseEnterPhone.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid 10-digit phone number'**
  String get pleaseEnterPhone;

  /// No description provided for @pleaseSelectDob.
  ///
  /// In en, this message translates to:
  /// **'Please select your date of birth'**
  String get pleaseSelectDob;

  /// No description provided for @pleaseEnterFeet.
  ///
  /// In en, this message translates to:
  /// **'Please enter feet'**
  String get pleaseEnterFeet;

  /// No description provided for @pleaseEnterValidFeet.
  ///
  /// In en, this message translates to:
  /// **'Please enter valid feet (1-8)'**
  String get pleaseEnterValidFeet;

  /// No description provided for @pleaseEnterValidInches.
  ///
  /// In en, this message translates to:
  /// **'Please enter valid inches (0-11)'**
  String get pleaseEnterValidInches;

  /// No description provided for @pleaseEnterEducation.
  ///
  /// In en, this message translates to:
  /// **'Please enter your education qualification'**
  String get pleaseEnterEducation;

  /// No description provided for @pleaseEnterOccupation.
  ///
  /// In en, this message translates to:
  /// **'Please enter your occupation'**
  String get pleaseEnterOccupation;

  /// No description provided for @pleaseEnterCity.
  ///
  /// In en, this message translates to:
  /// **'Please enter your current city'**
  String get pleaseEnterCity;

  /// No description provided for @pleaseSelectPhoto.
  ///
  /// In en, this message translates to:
  /// **'Please select a profile photo'**
  String get pleaseSelectPhoto;

  /// No description provided for @pleaseUploadBiodata.
  ///
  /// In en, this message translates to:
  /// **'Please upload your biodata'**
  String get pleaseUploadBiodata;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get emailAddress;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @occupation.
  ///
  /// In en, this message translates to:
  /// **'Occupation'**
  String get occupation;

  /// No description provided for @education.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get education;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @profileUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully!'**
  String get profileUpdatedSuccessfully;

  /// No description provided for @errorUpdatingProfile.
  ///
  /// In en, this message translates to:
  /// **'Error updating profile'**
  String get errorUpdatingProfile;

  /// No description provided for @pleaseEnter.
  ///
  /// In en, this message translates to:
  /// **'Please enter {field}'**
  String pleaseEnter(String field);

  /// No description provided for @supportOurCause.
  ///
  /// In en, this message translates to:
  /// **'Support Our Cause'**
  String get supportOurCause;

  /// No description provided for @donateToHelp.
  ///
  /// In en, this message translates to:
  /// **'Donate to help people of Teli Samaj to grow more.'**
  String get donateToHelp;

  /// No description provided for @viewUnlimitedProfiles.
  ///
  /// In en, this message translates to:
  /// **'View Unlimited Profiles'**
  String get viewUnlimitedProfiles;

  /// No description provided for @viewUnlimitedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Access thousands of verified profiles.'**
  String get viewUnlimitedSubtitle;

  /// No description provided for @directMessaging.
  ///
  /// In en, this message translates to:
  /// **'Direct Messaging'**
  String get directMessaging;

  /// No description provided for @directMessagingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect directly with matches.'**
  String get directMessagingSubtitle;

  /// No description provided for @verifiedBadge.
  ///
  /// In en, this message translates to:
  /// **'Verified Badge'**
  String get verifiedBadge;

  /// No description provided for @verifiedBadgeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stand out with a premium badge.'**
  String get verifiedBadgeSubtitle;

  /// No description provided for @prioritySupport.
  ///
  /// In en, this message translates to:
  /// **'Priority Support'**
  String get prioritySupport;

  /// No description provided for @prioritySupportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get help whenever you need it.'**
  String get prioritySupportSubtitle;

  /// No description provided for @yearlyDonation.
  ///
  /// In en, this message translates to:
  /// **'Yearly Donation'**
  String get yearlyDonation;

  /// No description provided for @bestValue.
  ///
  /// In en, this message translates to:
  /// **'Best Value'**
  String get bestValue;

  /// No description provided for @payViaUpi.
  ///
  /// In en, this message translates to:
  /// **'Pay ₹101 via UPI'**
  String get payViaUpi;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get processing;

  /// No description provided for @donationSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Donation Successful! Access Granted for 1 Year'**
  String get donationSuccessful;

  /// No description provided for @errorOpeningGateway.
  ///
  /// In en, this message translates to:
  /// **'Error opening payment gateway'**
  String get errorOpeningGateway;

  /// No description provided for @paymentSuccessfulUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Payment successful but failed to update status'**
  String get paymentSuccessfulUpdateError;

  /// No description provided for @paymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment Failed'**
  String get paymentFailed;

  /// No description provided for @externalWallet.
  ///
  /// In en, this message translates to:
  /// **'External Wallet'**
  String get externalWallet;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @users.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get users;

  /// No description provided for @posts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get posts;

  /// No description provided for @blocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get blocked;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @totalUsers.
  ///
  /// In en, this message translates to:
  /// **'Total Users'**
  String get totalUsers;

  /// No description provided for @paidUsers.
  ///
  /// In en, this message translates to:
  /// **'Paid Users'**
  String get paidUsers;

  /// No description provided for @totalPosts.
  ///
  /// In en, this message translates to:
  /// **'Total Posts'**
  String get totalPosts;

  /// No description provided for @recentUsers.
  ///
  /// In en, this message translates to:
  /// **'Recent Users'**
  String get recentUsers;

  /// No description provided for @markUnpaid.
  ///
  /// In en, this message translates to:
  /// **'Mark Unpaid'**
  String get markUnpaid;

  /// No description provided for @markPaid.
  ///
  /// In en, this message translates to:
  /// **'Mark Paid'**
  String get markPaid;

  /// No description provided for @removeAdmin.
  ///
  /// In en, this message translates to:
  /// **'Remove Admin'**
  String get removeAdmin;

  /// No description provided for @makeAdmin.
  ///
  /// In en, this message translates to:
  /// **'Make Admin'**
  String get makeAdmin;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @noPostsYet.
  ///
  /// In en, this message translates to:
  /// **'No posts yet'**
  String get noPostsYet;

  /// No description provided for @createFirstPost.
  ///
  /// In en, this message translates to:
  /// **'Create your first post!'**
  String get createFirstPost;

  /// No description provided for @newPost.
  ///
  /// In en, this message translates to:
  /// **'New Post'**
  String get newPost;

  /// No description provided for @createPost.
  ///
  /// In en, this message translates to:
  /// **'Create Post'**
  String get createPost;

  /// No description provided for @postType.
  ///
  /// In en, this message translates to:
  /// **'Post Type'**
  String get postType;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @content.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get content;

  /// No description provided for @publishPost.
  ///
  /// In en, this message translates to:
  /// **'Publish Post'**
  String get publishPost;

  /// No description provided for @addEmoji.
  ///
  /// In en, this message translates to:
  /// **'Add Emoji'**
  String get addEmoji;

  /// No description provided for @addImage.
  ///
  /// In en, this message translates to:
  /// **'Add Image'**
  String get addImage;

  /// No description provided for @addVideo.
  ///
  /// In en, this message translates to:
  /// **'Add Video'**
  String get addVideo;

  /// No description provided for @noBlockedUsers.
  ///
  /// In en, this message translates to:
  /// **'No blocked users'**
  String get noBlockedUsers;

  /// No description provided for @blockUser.
  ///
  /// In en, this message translates to:
  /// **'Block User'**
  String get blockUser;

  /// No description provided for @unblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get unblock;

  /// No description provided for @messages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messages;

  /// No description provided for @noMatchesYet.
  ///
  /// In en, this message translates to:
  /// **'No Matches Yet'**
  String get noMatchesYet;

  /// No description provided for @startChatting.
  ///
  /// In en, this message translates to:
  /// **'When you or another person accepts\nan interest, you can start chatting!'**
  String get startChatting;

  /// No description provided for @sayHello.
  ///
  /// In en, this message translates to:
  /// **'Say hello! 👋'**
  String get sayHello;

  /// No description provided for @startConversation.
  ///
  /// In en, this message translates to:
  /// **'Start the conversation!'**
  String get startConversation;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @typeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get typeMessage;

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You: '**
  String get you;

  /// No description provided for @unblockUser.
  ///
  /// In en, this message translates to:
  /// **'Unblock User'**
  String get unblockUser;

  /// No description provided for @youHaveBlocked.
  ///
  /// In en, this message translates to:
  /// **'You have blocked this user.'**
  String get youHaveBlocked;

  /// No description provided for @cannotReply.
  ///
  /// In en, this message translates to:
  /// **'You cannot reply to this conversation.'**
  String get cannotReply;

  /// No description provided for @sayHelloAndGetToKnow.
  ///
  /// In en, this message translates to:
  /// **'Say hello and get to know each other'**
  String get sayHelloAndGetToKnow;

  /// No description provided for @failedToSendMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to send message'**
  String get failedToSendMessage;

  /// No description provided for @userBlocked.
  ///
  /// In en, this message translates to:
  /// **'User blocked'**
  String get userBlocked;

  /// No description provided for @userUnblocked.
  ///
  /// In en, this message translates to:
  /// **'User unblocked'**
  String get userUnblocked;

  /// No description provided for @errorLoadingMessages.
  ///
  /// In en, this message translates to:
  /// **'Error loading messages'**
  String get errorLoadingMessages;

  /// No description provided for @basicInformation.
  ///
  /// In en, this message translates to:
  /// **'Basic Information'**
  String get basicInformation;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @height.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get height;

  /// No description provided for @locationCareer.
  ///
  /// In en, this message translates to:
  /// **'Location & Career'**
  String get locationCareer;

  /// No description provided for @contact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get contact;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @years.
  ///
  /// In en, this message translates to:
  /// **'years'**
  String get years;

  /// No description provided for @personalDetails.
  ///
  /// In en, this message translates to:
  /// **'Personal Details'**
  String get personalDetails;

  /// No description provided for @detailedBiodata.
  ///
  /// In en, this message translates to:
  /// **'Detailed Biodata'**
  String get detailedBiodata;

  /// No description provided for @viewFullFamilyDetails.
  ///
  /// In en, this message translates to:
  /// **'View full family details'**
  String get viewFullFamilyDetails;

  /// No description provided for @chatNow.
  ///
  /// In en, this message translates to:
  /// **'Chat Now'**
  String get chatNow;

  /// No description provided for @removedFromSaved.
  ///
  /// In en, this message translates to:
  /// **'Removed from saved'**
  String get removedFromSaved;

  /// No description provided for @profileSavedMsg.
  ///
  /// In en, this message translates to:
  /// **'Profile saved!'**
  String get profileSavedMsg;

  /// No description provided for @interestSentMsg.
  ///
  /// In en, this message translates to:
  /// **'Interest sent!'**
  String get interestSentMsg;

  /// No description provided for @interestAccepted.
  ///
  /// In en, this message translates to:
  /// **'Interest accepted!'**
  String get interestAccepted;

  /// No description provided for @interestDeclined.
  ///
  /// In en, this message translates to:
  /// **'Interest declined'**
  String get interestDeclined;

  /// No description provided for @newMessageFrom.
  ///
  /// In en, this message translates to:
  /// **'New message from {name}'**
  String newMessageFrom(String name);

  /// No description provided for @profilePhotoUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile photo updated!'**
  String get profilePhotoUpdated;

  /// No description provided for @errorMsg.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorMsg(String error);

  /// No description provided for @userMarkedPaid.
  ///
  /// In en, this message translates to:
  /// **'User marked as paid!'**
  String get userMarkedPaid;

  /// No description provided for @userMarkedUnpaid.
  ///
  /// In en, this message translates to:
  /// **'User marked as unpaid'**
  String get userMarkedUnpaid;

  /// No description provided for @adminAccessGranted.
  ///
  /// In en, this message translates to:
  /// **'Admin access granted!'**
  String get adminAccessGranted;

  /// No description provided for @adminAccessRevoked.
  ///
  /// In en, this message translates to:
  /// **'Admin access revoked'**
  String get adminAccessRevoked;

  /// No description provided for @userDeletedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'User deleted successfully'**
  String get userDeletedSuccessfully;

  /// No description provided for @postCreatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Post created successfully!'**
  String get postCreatedSuccessfully;

  /// No description provided for @postDeleted.
  ///
  /// In en, this message translates to:
  /// **'Post deleted'**
  String get postDeleted;

  /// No description provided for @enterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get enterValidEmail;

  /// No description provided for @emailAlreadyBlocked.
  ///
  /// In en, this message translates to:
  /// **'Email already blocked'**
  String get emailAlreadyBlocked;

  /// No description provided for @user.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get user;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @successStory.
  ///
  /// In en, this message translates to:
  /// **'Success Story'**
  String get successStory;

  /// No description provided for @announcement.
  ///
  /// In en, this message translates to:
  /// **'Announcement'**
  String get announcement;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// No description provided for @loadingDocument.
  ///
  /// In en, this message translates to:
  /// **'Loading document...'**
  String get loadingDocument;

  /// No description provided for @couldNotLoadBiodata.
  ///
  /// In en, this message translates to:
  /// **'Could not load biodata'**
  String get couldNotLoadBiodata;

  /// No description provided for @unsupportedFormat.
  ///
  /// In en, this message translates to:
  /// **'The file format may not be supported'**
  String get unsupportedFormat;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @deleteUser.
  ///
  /// In en, this message translates to:
  /// **'Delete User'**
  String get deleteUser;

  /// No description provided for @deleteUserConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"? This action cannot be undone.'**
  String deleteUserConfirm(String name);

  /// No description provided for @enterTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter title...'**
  String get enterTitle;

  /// No description provided for @writePost.
  ///
  /// In en, this message translates to:
  /// **'Write your post...'**
  String get writePost;

  /// No description provided for @mediaOptional.
  ///
  /// In en, this message translates to:
  /// **'Media (Optional)'**
  String get mediaOptional;

  /// No description provided for @pleaseEnterTitle.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title'**
  String get pleaseEnterTitle;

  /// No description provided for @uploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed'**
  String get uploadFailed;

  /// No description provided for @deletePost.
  ///
  /// In en, this message translates to:
  /// **'Delete Post'**
  String get deletePost;

  /// No description provided for @deletePostConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this post?'**
  String get deletePostConfirm;

  /// No description provided for @unblockUserConfirm.
  ///
  /// In en, this message translates to:
  /// **'Unblock {email}?'**
  String unblockUserConfirm(String email);

  /// No description provided for @blockedAt.
  ///
  /// In en, this message translates to:
  /// **'Blocked: {date}'**
  String blockedAt(String date);

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @addCity.
  ///
  /// In en, this message translates to:
  /// **'Add city'**
  String get addCity;

  /// No description provided for @addJob.
  ///
  /// In en, this message translates to:
  /// **'Add job'**
  String get addJob;

  /// No description provided for @addDob.
  ///
  /// In en, this message translates to:
  /// **'Add DOB'**
  String get addDob;

  /// No description provided for @free.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get free;

  /// No description provided for @paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'mr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'mr':
      return AppLocalizationsMr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
