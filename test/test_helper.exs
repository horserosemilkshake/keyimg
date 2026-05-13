ExUnit.start()

Application.ensure_all_started(:keyimg)

alias Keyimg.{Cache, Metadata}

storage_root = Application.fetch_env!(:keyimg, :storage_root)
File.rm_rf!(storage_root)
File.mkdir_p!(storage_root)

:ok = Metadata.clear_all()
:ok = Cache.clear()
