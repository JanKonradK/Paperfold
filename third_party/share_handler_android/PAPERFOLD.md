# share_handler_android (Paperfold copy)

Source: https://github.com/Anxcye/share_handler, commit
eeaa04d22e7e70babb55b6825b9ca7016e89c89a, directory `share_handler_android`.
License: MIT (see LICENSE).

## Change

The plugin copies a shared file into the app cache. It used the sender's
display name as the file name. A display name such as `../databases/x` wrote
the file outside the cache directory.

`safeFileName` in `FileDirectory.kt` keeps only the last path segment. It
rejects an empty name, `.`, and `..`. Both copy paths use it.

Remove this copy when the upstream fork contains the same check.
