{
  object_merge(array)::
    std.foldl(function(total, obj) total + obj, array, {}),
  sanitize_kube_name(name)::
    std.strReplace(name, '_', '-'),
}
