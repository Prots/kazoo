-module(kz_attachment).

-include("kz_att.hrl").

-callback put_attachment(kz_data:connection()
                        ,ne_binary()
                        ,ne_binary()
                        ,ne_binary()
                        ,ne_binary()
                        ,kz_data:options()
                        ) -> {ok, iodata()} | {error, any()}.

-callback fetch_attachment(kz_data:connection()
                          ,ne_binary()
                          ,ne_binary()
                          ,ne_binary()
                          ) -> any().
