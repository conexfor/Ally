import 'package:ally_core/ally_core.dart';

import '../local/local_store.dart';
import '../remote/ally_api.dart';

/// Contactos, solicitudes y grupos. Requieren conexión (involucran a otras
/// personas); el resultado se guarda localmente para usarlo sin conexión.
class SocialRepository {
  final AllyApi api;
  final LocalStore store;

  SocialRepository(this.api, this.store);

  Stream<List<Contact>> watchContacts() => store.watchContacts();
  Stream<List<Group>> watchGroups() => store.watchGroups();

  Future<void> refresh() async {
    await store.saveContacts(await api.contacts());
    await store.saveGroups(await api.groups());
  }

  Future<List<PublicUser>> search(String query) => api.searchUsers(query.trim());

  Future<Contact> request({String? userId, String? username, String? email, String? phone}) async {
    final contact = await api.requestConnection(userId: userId, username: username, email: email, phone: phone);
    await _refreshContacts();
    return contact;
  }

  Future<Contact> accept(String connectionId) async {
    final contact = await api.acceptConnection(connectionId);
    await _refreshContacts();
    return contact;
  }

  Future<void> reject(String connectionId) async {
    await api.rejectConnection(connectionId);
    await _refreshContacts();
  }

  Future<void> block(String connectionId) async {
    await api.blockConnection(connectionId);
    await _refreshContacts();
  }

  Future<void> unblock(String connectionId) async {
    await api.unblockConnection(connectionId);
    await _refreshContacts();
  }

  Future<void> remove(String connectionId) async {
    await api.removeConnection(connectionId);
    await _refreshContacts();
  }

  Future<Contact> updatePermissions(String connectionId, ConnectionPermissions permissions) async {
    final contact = await api.updatePermissions(connectionId, permissions);
    await _refreshContacts();
    return contact;
  }

  Future<InvitationCode> invitationCode() => api.invitationCode();

  Future<Contact> connectWithCode(String code) async {
    final contact = await api.connectWithCode(code);
    await _refreshContacts();
    return contact;
  }

  Future<void> _refreshContacts() async => store.saveContacts(await api.contacts());
  Future<void> _refreshGroups() async => store.saveGroups(await api.groups());

  // ------------------------------------------------------------------ grupos

  Future<Group> createGroup(String name, {String? description, List<String> memberIds = const []}) async {
    final group = await api.createGroup(name, description: description, memberIds: memberIds);
    await _refreshGroups();
    return group;
  }

  Future<Group> updateGroup(String id, String name, String? description, {GroupAlarmPolicy? alarmPolicy}) async {
    final group = await api.updateGroup(id, name, description, alarmPolicy: alarmPolicy);
    await _refreshGroups();
    return group;
  }

  Future<void> deleteGroup(String id) async {
    await api.deleteGroup(id);
    await _refreshGroups();
  }

  Future<Group> addMembers(String id, List<String> userIds) async {
    final group = await api.addMembers(id, userIds);
    await _refreshGroups();
    return group;
  }

  Future<void> removeMember(String id, String userId) async {
    await api.removeMember(id, userId);
    await _refreshGroups();
  }

  Future<Group> setRole(String id, String userId, GroupRole role) async {
    final group = await api.setMemberRole(id, userId, role);
    await _refreshGroups();
    return group;
  }

  Future<Group> acceptGroup(String id) async {
    final group = await api.acceptGroup(id);
    await _refreshGroups();
    return group;
  }

  Future<void> leaveGroup(String id) async {
    await api.leaveGroup(id);
    await _refreshGroups();
  }

  Future<Group> updateMembership(String id, {required bool allowAlarms, required bool autoAccept}) async {
    final group = await api.updateGroupMembership(id, allowAlarms: allowAlarms, autoAccept: autoAccept);
    await _refreshGroups();
    return group;
  }
}
