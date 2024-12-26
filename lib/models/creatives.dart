/// Copyright (c) 2024, Truecopy Credentials Private Limited - All Rights Reserved.
/// Unauthorized copying or redistribution of this file in source and binary forms via any medium is strictly prohibited.

import 'package:intl/intl.dart';
/**
 * to handgle and use the response from the fetchCreatives api call.
 * @since 1.0.0
 */
class Creative {
  final String id;
  final String caption;
  final String description;
  final String status;
  final String notes;
  final bool liked;
  final int likes;
  final bool showLikesCount;
  final bool favorite;
  final bool showFavorite;
  final int? publicAccess;
  final String? folderId;
  final String dibbedUrl;
  final String certificateUrl;
  final String originalUrl;
  final String attachmentUrl;
  final String thumbUrl;
  final String mthumbUrl;
  final String sharingUrl;
  final List<String>? tagsList;
  final int? flagged;
  final List<dynamic>? sreqLikesList;
  final bool? showCommentsCount;
  final int? comments;
  final List<dynamic>? sreqCommentsList;
  final DateTime? createdOn;
  final List<SreqVersion>? sreqVersionList;
  final bool? showShareCount;
  final int? shares;
  final List<String>? postMenuOptions;
  final bool? archived;
  final String? dataType;
  final CommnunityProfileInfo? profileInfo;
  final SreqTransferData? sreqTransferData;

  Creative({
    required this.id,
    required this.caption,
    required this.description,
    required this.notes,
    required this.liked,
    required this.likes,
    required this.showLikesCount,
    required this.favorite,
    required this.showFavorite,
    this.publicAccess,
    this.folderId,
    required this.status,
    required this.dibbedUrl,
    required this.certificateUrl,
    required this.originalUrl,
    required this.attachmentUrl,
    required this.thumbUrl,
    required this.mthumbUrl,
    required this.sharingUrl,
    this.tagsList,
    this.flagged,
    this.sreqLikesList,
    this.showCommentsCount,
    this.comments,
    this.sreqCommentsList,
    this.createdOn,
    this.sreqVersionList,
    this.showShareCount,
    this.shares,
    this.postMenuOptions,
    this.archived,
    this.profileInfo,
    this.dataType,
    this.sreqTransferData,
  });

  factory Creative.fromJson(Map<String, dynamic> json) {
    // final String createdOnString = json['createdOn'];
    // final RegExp regExp = RegExp(r'(\w{3} \d{1,2}, \d{4} \d{1,2}:\d{2}:\d{2} [APM]{2})');
    // final Match? match = regExp.firstMatch(createdOnString);
    // DateTime createdOn = DateTime.now();
    final profileInfoJson = json['profileInfo'];
    final sreqTransferDataJson = json['sreqTransferData'];
    final DateFormat isoFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSZ");
    final DateFormat customFormat = DateFormat('MMM d, yyyy h:mm:ss a');

    String dateString = json['createdOn'];

    DateTime parsedDate;
    if (dateString.contains('-') && dateString.contains('T')) {
      // If it's in ISO format, parse it using isoFormat
      parsedDate = isoFormat.parse(dateString).toLocal();
    } else {
      // Otherwise, parse it using customFormat
      parsedDate = customFormat.parse(dateString).toLocal();
    }


    return Creative(
      id: json['id'] ?? "",
      caption: json['caption'] ?? "",
      description: json['description'] ?? "",
      notes: json['notes'] ?? "",
      liked: json['liked'] ?? false,
      likes: json['likes'] ?? 0,
      showLikesCount: json['showLikesCount'] ?? false,
      favorite: json['favorite'] ?? false,
      showFavorite: json['showFavorite'] ?? false,
      publicAccess: json['publicAccess'] ?? 0,
      folderId: json['folder_id'] ?? "",
      dibbedUrl: json['dibbedUrl'] ?? "",
      certificateUrl: json['certificateUrl'] ?? "",
      originalUrl: json['originalUrl'] ?? "",
      attachmentUrl: json['attachmentUrl'] ?? "",
      thumbUrl: json['thumbUrl'] ?? "",
      mthumbUrl: json['mthumbUrl'] ?? "",
      sharingUrl: json['sharingUrl'] ?? "",
      tagsList: List<String>.from(json['tagsList'] ?? []),
      flagged: json['flagged'] ?? 0,
      status: json['status'],
      sreqLikesList: List<dynamic>.from(json['sreqLikesList'] ?? []),
      showCommentsCount: json['showCommentsCount'] ?? false,
      comments: json['comments'] ?? 0,
      sreqCommentsList: List<dynamic>.from(json['sreqCommentsList'] ?? []),
      createdOn: parsedDate,
      sreqVersionList: json['sreqVersionList'] != null
          ? List<SreqVersion>.from(json['sreqVersionList'].map((versionJson) => SreqVersion.fromJson(versionJson)))
          : [],
      showShareCount: json['showShareCount'] ?? false,
      shares: json['shares'] ?? 0,
      dataType: json['dataType'],
      postMenuOptions: List<String>.from(json['postMenuOptions'] ?? []),
      archived: json['archived'] ?? false,
      profileInfo: profileInfoJson != null ? CommnunityProfileInfo.fromJson(profileInfoJson) : null,
      sreqTransferData: sreqTransferDataJson != null ? SreqTransferData.fromJson(sreqTransferDataJson) : null,
    );
  }
  String get localNotifyTs {
    final formattedTime = DateFormat('MMM d, yyyy hh:mm:ss aZ').parse(DateFormat('MMM d, yyyy hh:mm:ss a').format(createdOn!), true);
    final localDateTime = formattedTime.toLocal();
    return DateFormat('MMM d, yyyy'/*hh:mm:ss a*/).format(localDateTime);
  }
}

class SreqTransferData {
  final String? id;
  final String? sreqId;
  final String? fromUser;
  final String? toUser;
  final bool? transferer;
  final bool? transferee;
  final String? status;


  SreqTransferData({
    this.id,
    this.sreqId,
    this.fromUser,
    this.toUser,
    this.transferer,
    this.transferee,
    this.status,
  });

  factory SreqTransferData.fromJson(Map<String, dynamic> json) {

    return SreqTransferData(
      id: json['id'] ?? "",
      sreqId: json['sreq_id'] ?? "",
      fromUser: json['fromUser'] ?? "",
      toUser: json['toUser'] ?? "",
      transferer: json['transferer'] ?? false,
      transferee: json['transferee'] ?? false,
      status: json['status'] ?? "",
    );
  }
}



class SreqVersion {
  final String? parentSreqId;
  final String? linkedSreqId;
  final DateTime? creationTs;

  SreqVersion({
    this.parentSreqId,
    this.linkedSreqId,
    this.creationTs,
  });

  factory SreqVersion.fromJson(Map<String, dynamic> json) {

    final DateFormat isoFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSZ");
    final DateFormat customFormat = DateFormat('MMM d, yyyy h:mm:ss a');

    String dateString = json['creation_ts'];

    DateTime parsedDate;
    if (dateString.contains('-') && dateString.contains('T')) {
      // If it's in ISO format, parse it using isoFormat
      parsedDate = isoFormat.parse(dateString);
    } else {
      // Otherwise, parse it using customFormat
      parsedDate = customFormat.parse(dateString);
    }
    // final DateFormat format = DateFormat('MMM d, yyyy h:mm:ss a');
    return SreqVersion(
      parentSreqId: json['parent_sreq_id'],
      linkedSreqId: json['linked_sreq_id'],
      creationTs: parsedDate,
    );
  }
}

class CommnunityProfileInfo {
  final String? bio;
  final String? photo;
  final String? wallpaper;
  final String? fullname;
  final String? userid;
  final String? handle;
  final int? rank;
  final bool? following;
  final bool? followedBy;
  final String? followingSnId;
  final String? followingRequestedDate;
  final String? followingAckDate;
  final String? followingStatus;
  final String? followedBySnId;
  final String? followedByRequestedDate;
  final String? followedByAckDate;
  final String? followedByStatus;
  final bool? mobileVerified;

  CommnunityProfileInfo({
    this.bio,
    this.photo,
    this.wallpaper,
    this.fullname,
    this.userid,
    this.handle,
    this.rank,
    this.following,
    this.followedBy,
    this.followingSnId,
    this.followingRequestedDate,
    this.followingAckDate,
    this.followingStatus,
    this.followedBySnId,
    this.followedByRequestedDate,
    this.followedByAckDate,
    this.followedByStatus,
    this.mobileVerified,
  });

  factory CommnunityProfileInfo.fromJson(Map<String, dynamic> json) {
    return CommnunityProfileInfo(
      bio: json['bio'],
      photo: json['photo'],
      wallpaper: json['wallpaper'],
      fullname: json['fullname'],
      userid: json['userid'],
      handle: json['handle'],
      rank: json['rank'],
      following: json['following'],
      followedBy: json['followedBy'],
      followingSnId: json['followingSnId'],
      followingRequestedDate: json['followingRequestedDate'],
      followingAckDate: json['followingAckDate'],
      followingStatus: json['followingStatus'],
      followedBySnId: json['followedBySnId'],
      followedByRequestedDate: json['followedByRequestedDate'],
      followedByAckDate: json['followedByAckDate'],
      followedByStatus: json['followedByStatus'],
      mobileVerified: json['mobileVerified'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bio': bio,
      'photo': photo,
      'wallpaper': wallpaper,
      'fullname': fullname,
      'userid': userid,
      'handle': handle,
      'rank': rank,
      'following': following,
      'followedBy': followedBy,
      'followingSnId': followingSnId,
      'followingRequestedDate': followingRequestedDate,
      'followingAckDate': followingAckDate,
      'followingStatus': followingStatus,
      'followedBySnId': followedBySnId,
      'followedByRequestedDate': followedByRequestedDate,
      'followedByAckDate': followedByAckDate,
      'followedByStatus': followedByStatus,
      'mobileVerified': mobileVerified,
    };
  }
}
