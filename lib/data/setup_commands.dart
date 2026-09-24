import 'dart:math';

import 'paired_router.dart';

/// A password for the router's read-only user: letters and digits only,
/// since the RouterOS terminal treats `$` and `?` specially even inside
/// quotes. Look-alike characters (0/O, 1/l/I) are left out.
String generatePassword({int length = 24, Random? random}) {
  const alphabet = 'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rng = random ?? Random.secure();
  return String.fromCharCodes([
    for (var i = 0; i < length; i++)
      alphabet.codeUnitAt(rng.nextInt(alphabet.length)),
  ]);
}

/// RouterOS commands that prepare a router for Watchtower: a certificate for
/// the encrypted API service, signed by a small local CA because RouterOS
/// won't self-sign a server certificate, and a read-only user.
List<String> setupCommands(
  String password, {
  String user = PairedRouter.defaultUser,
}) => [
  '/certificate add name=watchtower-ca common-name=watchtower-ca '
      'days-valid=3650 key-usage=key-cert-sign,crl-sign',
  '/certificate sign watchtower-ca',
  '/certificate add name=watchtower common-name=watchtower days-valid=3650 '
      'key-usage=digital-signature,key-encipherment,tls-server',
  '/certificate sign watchtower ca=watchtower-ca',
  '/ip service set api-ssl certificate=watchtower disabled=no',
  '/user group add name=watchtower-ro policy=read,api',
  '/user add name=$user group=watchtower-ro password="$password"',
];

/// Replaces the last setup command when the user already exists.
String resetPasswordCommand(
  String password, {
  String user = PairedRouter.defaultUser,
}) => '/user set $user password="$password"';

/// Shows the fingerprint to compare with the one the app displays.
const certificateCheckCommand =
    '/certificate print detail where name=watchtower';
