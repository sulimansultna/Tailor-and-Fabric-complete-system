import 'package:flutter/widgets.dart';

import 'auth_service.dart';

String authText(BuildContext context, String key) {
  final language = Localizations.localeOf(context).languageCode;
  const en = {
    'loginTitle': 'Owner sign in',
    'loginSubtitle': 'Sign in to continue to your shop.',
    'username': 'Username',
    'password': 'Password',
    'signIn': 'Sign in',
    'remember': 'Remember me on this computer',
    'rememberHint':
        'Stores a secure sign-in token on this Windows account for 30 days.',
    'forgot': 'Forgot password?',
    'initialTitle': 'Set a new owner password',
    'initialHint':
        'The starter password must be replaced before using the shop.',
    'newPassword': 'New password',
    'confirmPassword': 'Confirm password',
    'saveContinue': 'Save and continue',
    'recoveryTitle': 'Save your recovery code',
    'recoveryHint': 'Keep this code somewhere private and separate from this computer. It can reset your password.',
    'copy': 'Copy code',
    'saveCode': 'Save code',
    'print': 'Print',
    'ack': 'I saved this recovery code somewhere safe',
    'continue': 'Continue',
    'forgotTitle': 'Recover owner account',
    'recoveryCode': 'Recovery code',
    'resetPassword': 'Reset password',
    'cancel': 'Cancel',
    'invalidCredentials': 'Username or password is incorrect.',
    'invalidRecovery': 'Username or recovery code is incorrect.',
    'invalidCurrentPassword': 'Current password is incorrect.',
    'passwordTooShort': 'Password must contain at least 8 characters.',
    'passwordTooLong': 'Password is too long.',
    'invalidUsernameFormat':
        'Use 3–32 letters, numbers, dots, underscores, or hyphens.',
    'cooldown': 'Too many attempts. Try again in {seconds} seconds.',
    'passwordMismatch': 'Passwords do not match.',
    'rememberUnavailable': 'Secure remember-me storage is unavailable; sign in will work for this session only.',
    'copied': 'Recovery code copied.',
    'saved': 'Recovery code saved.',
    'codeRequired': 'Save or copy the code and acknowledge before continuing.',
    'securityTitle': 'Account and security',
    'changeUsername': 'Change username',
    'changePassword': 'Change password',
    'regenerate': 'Regenerate recovery code',
    'sessionStatus': 'Remembered sign-in',
    'forget': 'Forget this computer',
    'signOut': 'Sign out',
    'currentPassword': 'Current password',
    'updatedSignIn':
        'Security details updated. Sign in again with your new credentials.',
    'forgotten': 'This computer will ask for your password next time.',
    'securityNote': 'This login controls access to this app on this Windows account. It does not encrypt shop files against other Windows users with file access.',
    'restorePassword': 'Confirm your password to restore this backup. The restore replaces shop records and signs you out.',
    'account': 'Account',
    'close': 'Close',
    'recoveryUnavailable': 'Set up a recovery code after signing in before you can recover the account.',
  };
  const ps = {
    'loginTitle': 'د مالک ننوتل',
    'loginSubtitle': 'دوکان ته د دوام لپاره ننوځئ.',
    'username': 'کارن نوم',
    'password': 'پټ نوم',
    'signIn': 'ننوتل',
    'remember': 'په دې کمپیوټر کې مې په یاد وساته',
    'rememberHint': 'د دې وینډوز حساب لپاره د ۳۰ ورځو خوندي ننوتلو نښه ساتي.',
    'forgot': 'پټ نوم مو هېر شوی؟',
    'initialTitle': 'د مالک نوی پټ نوم وټاکئ',
    'initialHint': 'د دوکان تر کارولو مخکې لومړنی پټ نوم بدل کړئ.',
    'newPassword': 'نوی پټ نوم',
    'confirmPassword': 'پټ نوم تایید کړئ',
    'saveContinue': 'خوندي او دوام',
    'recoveryTitle': 'د بېرته ترلاسه کولو کوډ وساتئ',
    'recoveryHint': 'کوډ په خوندي او له دې کمپیوټر څخه جلا ځای کې وساتئ. دا کوډ پټ نوم بېرته ټاکي.',
    'copy': 'کوډ کاپي',
    'saveCode': 'کوډ خوندي کول',
    'print': 'چاپ',
    'ack': 'ما دا کوډ په خوندي ځای کې وساته',
    'continue': 'دوام',
    'forgotTitle': 'د مالک حساب بېرته ترلاسه کول',
    'recoveryCode': 'د بېرته ترلاسه کولو کوډ',
    'resetPassword': 'پټ نوم بدلول',
    'cancel': 'لغوه',
    'invalidCredentials': 'کارن نوم یا پټ نوم ناسم دی.',
    'invalidRecovery': 'کارن نوم یا د بېرته ترلاسه کولو کوډ ناسم دی.',
    'invalidCurrentPassword': 'اوسنی پټ نوم ناسم دی.',
    'passwordTooShort': 'پټ نوم باید لږ تر لږه ۸ توري ولري.',
    'passwordTooLong': 'پټ نوم ډېر اوږد دی.',
    'invalidUsernameFormat':
        'له ۳ تر ۳۲ تورو پورې توري، شمېرې، ټکي یا کرښې وکاروئ.',
    'cooldown':
        'د ډېرو هڅو له امله بند دی. {seconds} ثانیې وروسته بیا هڅه وکړئ.',
    'passwordMismatch': 'پټ نومونه سره برابر نه دي.',
    'rememberUnavailable':
        'خوندي یاد ساتل نشته؛ یوازې د دې ناستې لپاره به ننوتل فعال وي.',
    'copied': 'د بېرته ترلاسه کولو کوډ کاپي شو.',
    'saved': 'کوډ خوندي شو.',
    'codeRequired': 'تر دوام مخکې کوډ خوندي یا کاپي او تایید کړئ.',
    'securityTitle': 'حساب او امنیت',
    'changeUsername': 'کارن نوم بدلول',
    'changePassword': 'پټ نوم بدلول',
    'regenerate': 'د بېرته ترلاسه کولو نوی کوډ',
    'sessionStatus': 'یاد ساتل شوی ننوتل',
    'forget': 'دا کمپیوټر هېرول',
    'signOut': 'وتل',
    'currentPassword': 'اوسنی پټ نوم',
    'updatedSignIn': 'امنیتي معلومات بدل شول. د نوي معلوماتو سره بیا ننوځئ.',
    'forgotten': 'دا کمپیوټر به بل ځل پټ نوم وغواړي.',
    'securityNote': 'دا ننوتل په دې وینډوز حساب کې اپلېکېشن ته لاسرسی کنټرولوي. د هغو کاروونکو پر وړاندې د دوکان فایلونه نه کوډوي چې فایلونو ته لاسرسی لري.',
    'restorePassword': 'د شاتړ بېرته راګرځولو لپاره پټ نوم تایید کړئ. د دوکان معلومات بدلوي او تاسو باسي.',
    'account': 'حساب',
    'close': 'بندول',
    'recoveryUnavailable':
        'د حساب د بېرته ترلاسه کولو لپاره تر ننوتلو وروسته کوډ جوړ کړئ.',
  };
  const fa = {
    'loginTitle': 'ورود مالک',
    'loginSubtitle': 'برای ادامه به فروشگاه وارد شوید.',
    'username': 'نام کاربری',
    'password': 'رمز عبور',
    'signIn': 'ورود',
    'remember': 'مرا در این رایانه به خاطر بسپار',
    'rememberHint':
        'نشانهٔ ورود امن را برای ۳۰ روز در حساب ویندوز نگه می‌دارد.',
    'forgot': 'رمز عبور را فراموش کرده‌اید؟',
    'initialTitle': 'رمز عبور جدید مالک را تعیین کنید',
    'initialHint': 'پیش از استفاده از فروشگاه، رمز آغازین باید تغییر کند.',
    'newPassword': 'رمز عبور جدید',
    'confirmPassword': 'تأیید رمز عبور',
    'saveContinue': 'ذخیره و ادامه',
    'recoveryTitle': 'کد بازیابی را ذخیره کنید',
    'recoveryHint': 'کد را در جای امن و جدا از این رایانه نگه دارید. با آن می‌توانید رمز عبور را بازنشانی کنید.',
    'copy': 'کپی کد',
    'saveCode': 'ذخیره کد',
    'print': 'چاپ',
    'ack': 'این کد بازیابی را در جای امن ذخیره کردم',
    'continue': 'ادامه',
    'forgotTitle': 'بازیابی حساب مالک',
    'recoveryCode': 'کد بازیابی',
    'resetPassword': 'بازنشانی رمز عبور',
    'cancel': 'لغو',
    'invalidCredentials': 'نام کاربری یا رمز عبور نادرست است.',
    'invalidRecovery': 'نام کاربری یا کد بازیابی نادرست است.',
    'invalidCurrentPassword': 'رمز عبور فعلی نادرست است.',
    'passwordTooShort': 'رمز عبور باید دست‌کم ۸ نویسه داشته باشد.',
    'passwordTooLong': 'رمز عبور بیش از حد طولانی است.',
    'invalidUsernameFormat':
        'از ۳ تا ۳۲ حرف، عدد، نقطه، زیرخط یا خط تیره استفاده کنید.',
    'cooldown': 'تلاش‌های زیاد انجام شد. {seconds} ثانیه بعد دوباره تلاش کنید.',
    'passwordMismatch': 'رمزهای عبور یکسان نیستند.',
    'rememberUnavailable':
        'ذخیره‌سازی امن ورود در دسترس نیست؛ ورود فقط برای این نشست فعال است.',
    'copied': 'کد بازیابی کپی شد.',
    'saved': 'کد ذخیره شد.',
    'codeRequired': 'پیش از ادامه کد را ذخیره یا کپی و تأیید کنید.',
    'securityTitle': 'حساب و امنیت',
    'changeUsername': 'تغییر نام کاربری',
    'changePassword': 'تغییر رمز عبور',
    'regenerate': 'تولید کد بازیابی جدید',
    'sessionStatus': 'ورود به‌یادمانده',
    'forget': 'فراموش‌کردن این رایانه',
    'signOut': 'خروج',
    'currentPassword': 'رمز عبور فعلی',
    'updatedSignIn':
        'اطلاعات امنیتی تغییر کرد. دوباره با مشخصات جدید وارد شوید.',
    'forgotten': 'این رایانه دفعهٔ بعد رمز عبور را می‌خواهد.',
    'securityNote': 'این ورود فقط دسترسی به برنامه را در حساب ویندوز کنترل می‌کند و فایل‌های فروشگاه را در برابر کاربران دارای دسترسی فایل رمزگذاری نمی‌کند.',
    'restorePassword': 'برای بازیابی این پشتیبان، رمز عبور را تأیید کنید. اطلاعات فروشگاه جایگزین و از حساب خارج می‌شوید.',
    'account': 'حساب',
    'close': 'بستن',
    'recoveryUnavailable':
        'برای بازیابی حساب، پس از ورود یک کد بازیابی بسازید.',
  };
  final map = language == 'ps'
      ? ps
      : language == 'fa'
      ? fa
      : en;
  return map[key] ?? en[key] ?? key;
}

String authFailureText(BuildContext context, Object error) {
  if (error is! Exception) return authText(context, 'invalidCredentials');
  final message = error.toString();
  final key = message.contains('cooldown')
      ? 'cooldown'
      : message.contains('invalidRecovery')
      ? 'invalidRecovery'
      : message.contains('invalidCurrentPassword')
      ? 'invalidCurrentPassword'
      : message.contains('passwordTooShort')
      ? 'passwordTooShort'
      : message.contains('passwordTooLong')
      ? 'passwordTooLong'
      : message.contains('invalidUsernameFormat')
      ? 'invalidUsernameFormat'
      : 'invalidCredentials';
  final seconds = error is AuthFailure
      ? '${error.retryAfter?.inSeconds ?? 30}'
      : '30';
  return authText(context, key).replaceAll('{seconds}', seconds);
}
