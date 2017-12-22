%%%-------------------------------------------------------------------
%%% @copyright (C) 2017, 2600Hz INC
%%%
%%% @contributors
%%%-------------------------------------------------------------------
-module(webhooks_notifications).

-export([init/0
        ,bindings_and_responders/0
        ,account_bindings/1
        ,handle_event/2
        ]).

-include("webhooks.hrl").

-define(ID, kz_term:to_binary(?MODULE)).
-define(NAME, <<"Notifications Webhook">>).
-define(DESC, <<"Fire a webhook when a notification event is triggered in Kazoo">>).

-define(METADATA(Modifiers)
       ,kz_json:from_list([{<<"_id">>, ?ID}
                          ,{<<"name">>, ?NAME}
                          ,{<<"description">>, ?DESC}
                          ,{<<"modifiers">>, Modifiers}
                          ])
       ).

%%--------------------------------------------------------------------
%% @public
%% @doc
%% @end
%%--------------------------------------------------------------------
-spec init() -> 'ok'.
init() ->
    init(get_notifications_definition(), []).

-spec init(kz_api:kapi_definitions(), kz_json:objects()) -> 'ok'.
init([], Acc) ->
    _ = webhooks_util:init_metadata(?ID, ?METADATA(Acc)),
    'ok';
init([EventDefinition|Rest], Acc) ->
    Props = [{kz_api:definition_name(EventDefinition)
             ,[{<<"friendly_name">>, kz_api:definition_friendly_name(EventDefinition)}
              ,{<<"description">>, kz_api:definition_description(EventDefinition)}
              ]
             }
            ],
    init(Rest, [kz_json:from_list_recursive(Props) | Acc]).

%%--------------------------------------------------------------------
%% @public
%% @doc
%% @end
%%--------------------------------------------------------------------
-spec bindings_and_responders() -> {gen_listener:bindings(), gen_listener:responders()}.
bindings_and_responders() ->
    Bindings = bindings(),
    Responders = [{{?MODULE, 'handle_event'}
                  ,[{<<"notification">>, <<"*">>}]
                  }
                 ],
    {Bindings, Responders}.

-spec bindings() -> gen_listener:bindings().
bindings() ->
    RestrictTo =
    [{'notifications', [{'restrict_to'
                        ,[kz_api:definition_restrict_to(Definition)
                          || Definition <- get_notifications_definition()
                         ]
                        }
                       ]
     }
    ].

%%--------------------------------------------------------------------
%% @public
%% @doc
%% @end
%%--------------------------------------------------------------------
-spec account_bindings(ne_binary()) -> gen_listener:bindings().
account_bindings(_AccountId) -> [].

%%--------------------------------------------------------------------
%% @private
%% @doc
%% @end
%%--------------------------------------------------------------------
-spec handle_event(kz_json:object(), kz_proplist()) -> 'ok'.
handle_event(JObj, _Props) ->
    lager:debug("got event: ~p", [JObj]),
    kz_util:put_callid(JObj),

    EventName = kz_api:event_name(JObj),
    EventDefinition = kapi_notifications:api_definition(EventName),

    Validate = kz_api:definition_validate_fun(EventDefinition),
    'true' = Validate(JObj),

    AccountId = kapi_notifications:account_id(JObj),
    case webhooks_util:find_webhooks(?ID, AccountId) of
        [] ->
            lager:debug("no hooks to handle ~s for ~s", [EventName, AccountId]);
        Hooks ->
            Event = kz_json:normalize(JObj),
            Filtered = [Hook || Hook <- Hooks, match_action_type(Hook, EventName)],

            %% FIXME: should we sent notify_update? if yes how to send it when hooks successfully fired?
            webhooks_util:fire_hooks(Event, Filtered)
    end.

-spec match_action_type(webhook(), api_binary()) -> boolean().
match_action_type(#webhook{hook_event = <<"webhooks_notifications">>
                          ,custom_data='undefined'
                          }, _Type) ->
    'true';
match_action_type(#webhook{hook_event = <<"webhooks_notifications">>
                          ,custom_data=JObj
                          }, Type) ->
    kz_json:get_value(<<"type">>, JObj) =:= Type
        orelse kz_json:get_value(<<"type">>, JObj) =:= <<"all">>;
match_action_type(#webhook{}, _Type) ->
    'true'.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% @end
%%--------------------------------------------------------------------
-spec get_notifications_definition() -> kz_api:kapi_definitions().
get_notifications_definition() ->
    [Definition
     || Definition <- kapi_notifications:api_definitions(),
                      kz_api:definition_name(Definition) =/= <<"skel">>,
                      kz_api:definition_name(Definition) =/= <<"notify_update">>
    ].
