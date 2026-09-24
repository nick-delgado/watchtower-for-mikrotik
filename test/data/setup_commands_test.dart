import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/data/paired_router.dart';
import 'package:watchtower/data/setup_commands.dart';

void main() {
  test('generates long passwords the RouterOS terminal accepts as-is', () {
    final passwords = {for (var i = 0; i < 100; i++) generatePassword()};
    expect(passwords, hasLength(100));
    for (final password in passwords) {
      expect(password, matches(RegExp(r'^[a-zA-Z2-9]{24}$')));
      expect(password, isNot(matches(RegExp('[01lIoO]'))));
    }
  });

  test('creates the certificates, a read-only group and the user', () {
    final commands = setupCommands('Abc234');
    expect(commands, hasLength(7));
    expect(commands, contains('/certificate sign watchtower ca=watchtower-ca'));
    expect(
      commands,
      contains('/user group add name=watchtower-ro policy=read,api'),
    );
    expect(
      commands.last,
      '/user add name=watchtower group=watchtower-ro password="Abc234"',
    );
    expect(
      resetPasswordCommand('Abc234'),
      '/user set watchtower password="Abc234"',
    );
  });

  test('stores a paired router as JSON', () {
    const router = PairedRouter(
      host: '10.0.0.1',
      port: 18729,
      user: 'monitor',
      password: 'secret',
      pin: 'ab12',
    );
    final copy = PairedRouter.fromJson(router.toJson());
    expect(copy.toJson(), router.toJson());
    expect(
      PairedRouter.fromJson({'host': 'h', 'password': 'p', 'pin': 'x'}).port,
      8729,
    );
  });
}
