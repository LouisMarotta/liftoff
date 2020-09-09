import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:lemmy_api_client/lemmy_api_client.dart';
import 'package:provider/provider.dart';

import '../stores/accounts_store.dart';
import '../util/text_color.dart';

class CommunitiesTab extends HookWidget {
  CommunitiesTab();

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var instancesFut = useMemoized(() {
      var accountsStore = context.watch<AccountsStore>();

      var futures = accountsStore.users.keys
          .where((e) => !accountsStore.isAnonymousFor(e))
          .map(
            (instanceUrl) =>
                LemmyApi(instanceUrl).v1.getSite().then((e) => e.site),
          )
          .toList();

      return Future.wait(futures);
    });
    var communitiesFut = useMemoized(() {
      var accountsStore = context.watch<AccountsStore>();

      var futures = accountsStore.users.keys
          .where((e) => !accountsStore.isAnonymousFor(e))
          .map(
            (instanceUrl) => LemmyApi(instanceUrl)
                .v1
                .getUserDetails(
                  sort: SortType.active,
                  savedOnly: false,
                  userId: accountsStore.defaultTokenFor(instanceUrl).payload.id,
                )
                .then((e) => e.follows),
          )
          .toList();

      return Future.wait(futures);
    });

    var communitiesSnap = useFuture(communitiesFut);
    var instancesSnap = useFuture(instancesFut);

    if (!communitiesSnap.hasData || !instancesSnap.hasData) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    var instances = instancesSnap.data;
    var communities = communitiesSnap.data;

    return Scaffold(
      appBar: AppBar(),
      body: Column(
        children: Iterable.generate(instances.length)
            .map(
              (i) => Column(
                children: [
                  ListTile(
                    leading: CachedNetworkImage(
                      height: 50,
                      width: 50,
                      imageUrl: instances[i].icon,
                      imageBuilder: (context, imageProvider) => Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: DecorationImage(
                              fit: BoxFit.cover, image: imageProvider),
                        ),
                      ),
                      errorWidget: (_, __, ___) => SizedBox(width: 50),
                    ),
                    title: Text(
                      instances[i].name,
                      style: theme.textTheme.headline6,
                    ),
                  ),
                  for (var comm in communities[i])
                    Padding(
                      padding: const EdgeInsets.only(left: 50),
                      child: ListTile(
                        dense: true,
                        leading: CachedNetworkImage(
                          height: 30,
                          width: 30,
                          imageUrl: instances[i].icon,
                          imageBuilder: (context, imageProvider) => Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              image: DecorationImage(
                                  fit: BoxFit.cover, image: imageProvider),
                            ),
                          ),
                          errorWidget: (_, __, ___) => SizedBox(width: 30),
                        ),
                        title: Text('!${comm.communityName}'),
                        trailing: _CommunitySubscribeToggle(
                          instanceUrl: comm.communityActorId.split('/')[2],
                          communityId: comm.communityId,
                        ),
                      ),
                    )
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _CommunitySubscribeToggle extends HookWidget {
  final int communityId;
  final String instanceUrl;

  _CommunitySubscribeToggle(
      {@required this.instanceUrl, @required this.communityId})
      : assert(instanceUrl != null),
        assert(communityId != null);

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var subed = useState(true);
    var loading = useState(false);

    return InkWell(
      onTap: () async {
        loading.value = true;
        try {
          await LemmyApi(instanceUrl).v1.followCommunity(
                communityId: communityId,
                follow: !subed.value,
                auth: context
                    .read<AccountsStore>()
                    .defaultTokenFor(instanceUrl)
                    .raw,
              );
          subed.value = !subed.value;
        } on Exception catch (err) {
          Scaffold.of(context).showSnackBar(SnackBar(
            content: Text('Failed to ${subed.value ? 'un' : ''}follow: $err'),
          ));
        }
        loading.value = false;
      },
      child: Container(
        decoration: loading.value
            ? null
            : BoxDecoration(
                color: subed.value ? theme.accentColor : null,
                border: Border.all(color: theme.accentColor),
                borderRadius: BorderRadius.circular(5),
              ),
        child: loading.value
            ? Container(
                width: 20, height: 20, child: CircularProgressIndicator())
            : Icon(
                subed.value ? Icons.done : Icons.add,
                color: subed.value
                    ? textColorBasedOnBackground(theme.accentColor)
                    : theme.accentColor,
                size: 20,
              ),
      ),
    );
  }
}
