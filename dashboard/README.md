# StudySis admin dashboard

See the repository root `README.md` for Firebase setup, environment variables, and run commands.

## Team Content Studio access

Dashboard sign-in uses Firebase Authentication Email/Password accounts plus a
protected Firestore access document at `dashboard_access/{uid}`. A successful
Firebase sign-in alone does not grant dashboard access. The document must be
active, valid, and belong to the signed-in UID.

Valid Form 2 subject IDs are:

`bahasa_melayu`, `english`, `math`, `science`, `sejarah`, `geography`, `rbt`,
`pendidikan_islam`, `pjk`, and `seni`.

Both active roles can access every verified subject. The deprecated
`subjectIds` field may be omitted:

```json
{
  "role": "admin",
  "active": true,
  "displayName": "Ameerul Iman",
  "email": "admin@example.com"
}
```

Existing editor documents that still contain `subjectIds` remain valid, but the
field is ignored for visibility and authorization:

```json
{
  "role": "editor",
  "active": true,
  "displayName": "Team Member",
  "email": "editor@example.com",
  "subjectIds": ["science", "rbt"]
}
```

`displayName`, `email`, and legacy `subjectIds` are informational.
Authorization uses the Firebase Auth UID, role, active flag, and the verified
subject ID in the curriculum path. Active editors can create and edit draft
modules and draft structured content in all ten verified subjects, including
drafts created by another editor. Only admins can create or change curriculum
items, run curriculum setup, or publish/archive content. Dashboard clients
cannot create, update, or delete access documents.

### Manual bootstrap

1. In Firebase Console, open **Authentication > Users** and add an
   Email/Password user for the administrator or teammate.
2. Copy the new user's UID. Do not use the email address as the Firestore
   document ID.
3. Open **Firestore Database** and create the `dashboard_access` collection if
   it does not exist.
4. Create a document whose document ID is exactly that Firebase Auth UID.
5. Add `role` as `admin` or `editor` and `active` as a boolean. Add
   `displayName` and `email` only as optional string metadata. Do not add
   `subjectIds` to new records; old records containing it require no migration.
6. Deploy the updated Firestore rules before expecting team authoring access:
   `firebase deploy --only firestore:rules`.
7. The teammate can then sign in through the existing dashboard login form.

Access management remains a trusted Firebase Console operation in this sprint.
No collaborator-management UI, service-account key, Flutter change, or AI
authoring flow is included.
