@preconcurrency import FirebaseFirestore
import Foundation

enum FirebaseDocumentCodec {
    static func post(from snapshot: DocumentSnapshot) -> SkyPost? {
        guard let data = snapshot.data(),
              let ownerUid = data["ownerUid"] as? String,
              let localDate = LocalDate(docID: snapshot.documentID),
              let capturedAt = date(from: data["capturedAt"]),
              let imagePath = data["imagePath"] as? String,
              let thumbPath = data["thumbPath"] as? String,
              let skyColorHex = data["skyColorHex"] as? String,
              let skyColor = SkyColor(hex: skyColorHex)
        else { return nil }

        let uploadedAt = date(from: data["uploadedAt"]) ?? capturedAt
        return SkyPost(
            ownerUid: ownerUid,
            localDate: localDate,
            capturedAt: capturedAt,
            uploadedAt: uploadedAt,
            imagePath: imagePath,
            thumbPath: thumbPath,
            skyColor: skyColor,
            minutesFromGoal: integer(from: data["minutesFromGoal"]),
            reactions: data["reactions"] as? [String: String] ?? [:]
        )
    }

    static func postData(from draft: PostDraft) -> [String: Any] {
        [
            "ownerUid": draft.ownerUid,
            "capturedAt": Timestamp(date: draft.capturedAt),
            "uploadedAt": FieldValue.serverTimestamp(),
            "imagePath": draft.imagePath,
            "thumbPath": draft.thumbPath,
            "skyColorHex": draft.skyColor.hex,
            "minutesFromGoal": draft.minutesFromGoal,
            "reactions": [:] as [String: String],
        ]
    }

    static func profile(from snapshot: DocumentSnapshot) -> UserProfile? {
        guard let data = snapshot.data() else { return nil }
        let handle = (data["handle"] as? String).flatMap(Handle.init(raw:))
        return UserProfile(
            uid: snapshot.documentID,
            handle: handle,
            displayName: data["displayName"] as? String ?? "Sky Grid member",
            timezone: data["timezone"] as? String ?? TimeZone.current.identifier,
            wakeGoalMinutes: integer(from: data["wakeGoalMinutes"]),
            streakCurrent: integer(from: data["streakCurrent"]),
            streakLongest: integer(from: data["streakLongest"]),
            lastPostLocalDate: (data["lastPostLocalDate"] as? String).flatMap(LocalDate.init(docID:)),
            isPro: data["isPro"] as? Bool ?? false
        )
    }

    static func mutableProfileData(from profile: UserProfile) -> [String: Any] {
        [
            "displayName": profile.displayName,
            "timezone": profile.timezone,
            "wakeGoalMinutes": profile.wakeGoalMinutes,
        ]
    }

    static func friendship(from snapshot: DocumentSnapshot) -> Friendship? {
        guard let data = snapshot.data(),
              let members = data["members"] as? [String],
              members.count == 2,
              let statusRaw = data["status"] as? String,
              let status = FriendshipStatus(rawValue: statusRaw),
              let requestedBy = data["requestedBy"] as? String,
              let createdAt = date(from: data["createdAt"])
        else { return nil }

        return Friendship(
            pairId: snapshot.documentID,
            members: members.sorted(),
            status: status,
            requestedBy: requestedBy,
            requestedByHandle: (data["requestedByHandle"] as? String).flatMap(Handle.init(raw:)),
            recipientHandle: (data["recipientHandle"] as? String).flatMap(Handle.init(raw:)),
            createdAt: createdAt,
            blockedBy: (data["blockedBy"] as? [String]) ?? [],
            streakCurrent: optionalInteger(from: data["streakCurrent"]),
            streakLastMutualDate: (data["streakLastMutualDate"] as? String).flatMap(LocalDate.init(docID:))
        )
    }

    static func date(from value: Any?) -> Date? {
        switch value {
        case let timestamp as Timestamp:
            timestamp.dateValue()
        case let date as Date:
            date
        default:
            nil
        }
    }

    static func integer(from value: Any?) -> Int {
        switch value {
        case let value as Int:
            value
        case let value as NSNumber:
            value.intValue
        default:
            0
        }
    }

    static func optionalInteger(from value: Any?) -> Int? {
        switch value {
        case let value as Int:
            value
        case let value as NSNumber:
            value.intValue
        default:
            nil
        }
    }
}
