breed [pools pool]
breed [users user]
breed [transactions transaction]
extensions [py table]
globals [
  EPOCH
  MANAGEMENT_COST
  MAX_FEE
  MIN_PAYMENT
  BLOCK_REWARD
  MIN_FEE
  DEFAULT_PRECISION
  MIN_FEE_PAYMENT
  MAX_FEE_PAYMENT
  MIN_SP_INIT_BALANCE
  MAX_SP_INIT_BALANCE
  MIN_SP_INIT_STAKE
  MAX_SP_STAKE_RATIO
  MIN_TURTLE_INIT_BALANCE
  MAX_TURTLE_INIT_BALANCE
  MEMORY
  STRATEGY_COLORS
  STRATEGY_GREEDY
  STRATEGY_IMITATION
  STRATEGIES
  STRATEGY_NONE
  STRATEGY_Q_LEARNING
  STRATEGY_SARSA
  MU_FEE
  SIGMA_FEE
  MU_STAKE
  SIGMA_STAKE
  MU_TX
  SIGMA_TX
  STATES
  STATE_BALANCE
  STATE_LOSS
  STATE_GAIN
  STATE_STAKE_H
  STATE_STAKE_L
  STATE_FEE_H
  STATE_FEE_L
  STATE_GAIN_STAKE_H
  STATE_GAIN_STAKE_L
  STATE_GAIN_FEE_H
  STATE_GAIN_FEE_L
  STATE_LOSS_STAKE_H
  STATE_LOSS_STAKE_L
  STATE_LOSS_FEE_H
  STATE_LOSS_FEE_L
  STATE_GAIN_STAKE_H_FEE_H
  STATE_GAIN_STAKE_H_FEE_L
  STATE_GAIN_STAKE_L_FEE_H
  STATE_GAIN_STAKE_L_FEE_L
  STATE_LOSS_STAKE_H_FEE_H
  STATE_LOSS_STAKE_H_FEE_L
  STATE_LOSS_STAKE_L_FEE_H
  STATE_LOSS_STAKE_L_FEE_L
  ACTIONS
  ACTIONS_SIMPLE
  ACTION_NOP
  ACTION_STAKE_RAISE
  ACTION_STAKE_DROP
  ACTION_STAKE_NOP
  ACTION_FEE_RAISE
  ACTION_FEE_DROP
  ACTION_FEE_NOP
  ACTION_FEE_DYNAMIC
  ACTION_STAKE_RAISE_FEE_RAISE
  ACTION_STAKE_RAISE_FEE_DROP
  ACTION_STAKE_DROP_FEE_RAISE
  ACTION_STAKE_DROP_FEE_DROP
  DELTA_RAISE
  DELTA_DROP
  LR
  Q_EPSILON_
  DISCOUNT
  CURRENT_STATES
  CURRENT_ACTIONS
  NONE
  TRAINING_EPOCH
  STATE_GAIN_COUNTER
  MEMPOOL
  HISTORY_BALANCE_IDX
  HISTORY_STAKE_IDX
  HISTORY_GAIN_IDX
  HISTORY_FEE_IDX
  HISTORY_TX_COUNT_IDX
  HISTORY_STATE_IDX
  HISTORY_ACTION_IDX
  Q_TABLE_FILENAME
  WORLD_FILENAME
  EOP_REWARD
  EPISODE_LENGTH
  BALANCES
  STAKES
  TX_FEE_HISTORY
  AVG_TX_FEE_HISTORY
  POOLS_AVG_STAKE
  GAIN_THRESHOLD
  LOSS_THRESHOLD
  EPSILON_IMITATION
  GAMMA_FEE
  CURRENT_REWARD
  SARSA_NEXT_ACTION
  SORTED_VALIDATORS
  max_gain_stake_ratio_y
  min_gain_stake_ratio_y
  max_normalized_gain_y
  min_normalized_gain_y
  max_gain_fee_ratio_y
  min_gain_fee_ratio_y
  max_current_coll_tx_avg_y
  min_current_coll_tx_avg_y
  max_current_state_gain_count_avg_y
  min_current_state_gain_count_avg_y
  min_tot_gain_stake_ratio_y
  max_tot_gain_stake_ratio_y
  gs_ratio_min_max
]

users-own [ balance fee_spent ]
patches-own [ is_smart_contract ]
links-own [ ttl ]
pools-own [
  balance
  stake
  fee
  name
  strategy
  history
  niceness
  q_table
  state
  total_gain
  total_stake
  total_tx_count
  tx_fee_running_mean
  total_reward
  mngt_cost
  delta_reward
]
transactions-own [
  fee
  amount
  sender
  receiver
  timestamp
]

to setup
  py:setup py:python3
  ca
  const_init
  create-pools N_SP
  pools_init false
  create-users N_TURTLES
  users_init
  reset-ticks
end

to go
  (foreach range N_SP [ i ->
    table:put BALANCES i [balance] of pool i
    table:put STAKES i [stake] of pool i
  ])
  users_go
  process_smart_contract
  pools_go
  build_block
  if ticks > 0 [
    if ticks mod 2000 = 0 [ refund_users ]
    if ticks mod TICK_PER_EPOCH = 0 [
      choose_validators
      apply_cost
      pools_execute_strategy
      pools_update_history
      set EPOCH EPOCH + 1
      set CURRENT_REWARD 0
    ]
    if ticks mod 1000 = 0 and count transactions >= TX_PER_BLOCK * 5 [ replace_by_fee_last_n 2 * TX_PER_BLOCK ]
    if Q_TRAINING and ticks mod EPISODE_LENGTH = 0 [ reset_episode ]
  ]
  tick
end

to quick_checkpoint
  q_export_table Q_TABLE_FILENAME
  let world (word "world-" ticks ".csv")
  export-world world
end

to reset_episode
  q_export_table Q_TABLE_FILENAME
  export-world WORLD_FILENAME
  pools_init true
  ask transactions [ die ]
end

to apply_cost
  ask pools [
    set balance balance - mngt_cost
    set mngt_cost 0
  ]
end

to const_init
  set NONE "NONE"
  set EPOCH 0
  set MANAGEMENT_COST 2
  set BLOCK_REWARD 0.75 * MANAGEMENT_COST * TICK_PER_EPOCH
  set MAX_FEE 3
  set MIN_PAYMENT (MAX_FEE * 0.5)
  set DEFAULT_PRECISION 3
  set MIN_FEE 0.08
  set MIN_FEE_PAYMENT 0.05
  set MAX_FEE_PAYMENT 0.20
  set MAX_SP_INIT_BALANCE 1e4
  set MIN_SP_INIT_BALANCE MAX_SP_INIT_BALANCE / 2
  set MIN_SP_INIT_STAKE 1000
  set MAX_SP_STAKE_RATIO 0.8
  set MAX_TURTLE_INIT_BALANCE 3e3
  set MIN_TURTLE_INIT_BALANCE MAX_TURTLE_INIT_BALANCE * 0.2
  set MEMORY 10
  set HISTORY_BALANCE_IDX 0
  set HISTORY_STAKE_IDX 1
  set HISTORY_GAIN_IDX 2
  set HISTORY_FEE_IDX 3
  set HISTORY_TX_COUNT_IDX 4
  set HISTORY_STATE_IDX 5
  set HISTORY_ACTION_IDX 6
  set STRATEGY_NONE 0
  set STRATEGY_GREEDY 1
  set STRATEGY_IMITATION 2
  set STRATEGY_Q_LEARNING 3
  set STRATEGY_SARSA 4
  set STRATEGIES (list STRATEGY_NONE STRATEGY_GREEDY STRATEGY_IMITATION STRATEGY_Q_LEARNING STRATEGY_SARSA)
  set STRATEGY_COLORS (list yellow red green blue gray)
  set STATE_BALANCE 0
  set STATE_LOSS 2 ^ 1
  set STATE_GAIN 2 ^ 2
  set STATE_STAKE_L 2 ^ 3
  set STATE_STAKE_H 2 ^ 4
  set STATE_FEE_L 2 ^ 5
  set STATE_FEE_H 2 ^ 6
  set STATE_LOSS_STAKE_H STATE_LOSS + STATE_STAKE_H
  set STATE_LOSS_STAKE_L STATE_LOSS + STATE_STAKE_L
  set STATE_LOSS_FEE_H STATE_LOSS + STATE_FEE_H
  set STATE_LOSS_FEE_L STATE_LOSS + STATE_FEE_L
  set STATE_GAIN_STAKE_H STATE_GAIN + STATE_STAKE_H
  set STATE_GAIN_STAKE_L STATE_GAIN + STATE_STAKE_L
  set STATE_GAIN_FEE_H STATE_GAIN + STATE_FEE_H
  set STATE_GAIN_FEE_L STATE_GAIN + STATE_FEE_L
  set STATE_LOSS_STAKE_H_FEE_H STATE_LOSS + STATE_STAKE_H + STATE_FEE_H
  set STATE_LOSS_STAKE_H_FEE_L STATE_LOSS + STATE_STAKE_H + STATE_FEE_L
  set STATE_LOSS_STAKE_L_FEE_H STATE_LOSS + STATE_STAKE_L + STATE_FEE_H
  set STATE_LOSS_STAKE_L_FEE_L STATE_LOSS + STATE_STAKE_L + STATE_FEE_L
  set STATE_GAIN_STAKE_H_FEE_H STATE_GAIN + STATE_STAKE_H + STATE_FEE_H
  set STATE_GAIN_STAKE_H_FEE_L STATE_GAIN + STATE_STAKE_H + STATE_FEE_L
  set STATE_GAIN_STAKE_L_FEE_H STATE_GAIN + STATE_STAKE_L + STATE_FEE_H
  set STATE_GAIN_STAKE_L_FEE_L STATE_GAIN + STATE_STAKE_L + STATE_FEE_L
  set STATES (list
    STATE_BALANCE
    STATE_LOSS
    STATE_GAIN
    STATE_STAKE_H
    STATE_STAKE_L
    STATE_FEE_H
    STATE_FEE_L
    STATE_LOSS_STAKE_H
    STATE_LOSS_STAKE_L
    STATE_LOSS_FEE_H
    STATE_LOSS_FEE_L
    STATE_GAIN_STAKE_H
    STATE_GAIN_STAKE_L
    STATE_GAIN_FEE_H
    STATE_GAIN_FEE_L
    STATE_LOSS_STAKE_H_FEE_H
    STATE_LOSS_STAKE_H_FEE_L
    STATE_LOSS_STAKE_L_FEE_H
    STATE_LOSS_STAKE_L_FEE_L
    STATE_GAIN_STAKE_H_FEE_H
    STATE_GAIN_STAKE_H_FEE_L
    STATE_GAIN_STAKE_L_FEE_H
    STATE_GAIN_STAKE_L_FEE_L
  )
  set ACTION_NOP 0
  set ACTION_STAKE_RAISE 2 ^ 1
  set ACTION_STAKE_DROP 2 ^ 2
  set ACTION_FEE_RAISE 2 ^ 3
  set ACTION_FEE_DROP 2 ^ 4
  set ACTION_FEE_DYNAMIC 2 ^ 5
  set ACTION_STAKE_RAISE_FEE_RAISE ACTION_STAKE_RAISE + ACTION_FEE_RAISE
  set ACTION_STAKE_RAISE_FEE_DROP ACTION_STAKE_RAISE + ACTION_FEE_DROP
  set ACTION_STAKE_DROP_FEE_RAISE ACTION_STAKE_DROP + ACTION_FEE_RAISE
  set ACTION_STAKE_DROP_FEE_DROP ACTION_STAKE_DROP + ACTION_FEE_DROP
  set ACTIONS (list ACTION_NOP ACTION_STAKE_RAISE ACTION_STAKE_DROP ACTION_FEE_RAISE ACTION_FEE_DROP ACTION_STAKE_RAISE_FEE_RAISE ACTION_STAKE_RAISE_FEE_DROP ACTION_STAKE_DROP_FEE_RAISE ACTION_STAKE_DROP_FEE_DROP)
  set ACTIONS_SIMPLE (list ACTION_NOP ACTION_STAKE_RAISE ACTION_STAKE_DROP ACTION_FEE_RAISE ACTION_FEE_DROP)
  set CURRENT_ACTIONS n-values N_SP [ACTION_NOP]
  set DELTA_RAISE 0.01
  set DELTA_DROP 0.01
  set LR 0.1
  set DISCOUNT 0.6
  set TRAINING_EPOCH 0
  set STATE_GAIN_COUNTER table:from-list (map [[k v] -> list k v] range N_SP n-values N_SP [0])
  set Q_TABLE_FILENAME "q_table.json"
  set WORLD_FILENAME "world.csv"
  set EOP_REWARD -1
  set EPISODE_LENGTH 1e3
  set BALANCES table:make
  set STAKES table:make
  set TX_FEE_HISTORY []
  set AVG_TX_FEE_HISTORY 0
  set POOLS_AVG_STAKE 0
  set LOSS_THRESHOLD -1.5
  set GAIN_THRESHOLD 1.5
  set EPSILON_IMITATION 0.2
  set GAMMA_FEE 2.5
  set SARSA_NEXT_ACTION table:make
  set max_gain_stake_ratio_y 0.1
  set min_gain_stake_ratio_y -0.1
  set max_normalized_gain_y 1
  set max_gain_fee_ratio_y 0.01
  set min_gain_fee_ratio_y -0.01
  set max_current_coll_tx_avg_y 1
  set min_current_coll_tx_avg_y -1
  set max_current_state_gain_count_avg_y 1
  set min_current_state_gain_count_avg_y -1
  set min_tot_gain_stake_ratio_y -0.01
  set max_tot_gain_stake_ratio_y 0.01
  set gs_ratio_min_max map [_ -> list 0 1] range length STRATEGIES
end

;; ******************************************************************************** USERS ********************************************************************************
to users_init
  ;let b max list MIN_TURTLE_INIT_BALANCE random-normal ((MAX_TURTLE_INIT_BALANCE - MIN_TURTLE_INIT_BALANCE) / 2) ((MAX_TURTLE_INIT_BALANCE - MIN_TURTLE_INIT_BALANCE) / 4)
  let b MIN_TURTLE_INIT_BALANCE + random-float (MAX_TURTLE_INIT_BALANCE - MIN_TURTLE_INIT_BALANCE)
  ask users [
    set shape "computer workstation"
    set color white
    set balance b
    rt random 360
    fd 100
  ]
end

to users_go
  ask users [
    rt random 360
    fd 3
  ]
end

to refund_users
  if mean [balance] of users < (MAX_TURTLE_INIT_BALANCE / 2.0) [
    ask users [ set balance balance + MAX_TURTLE_INIT_BALANCE / 2]
    print "Turtles refund happened"
  ]
end
;; ******************************************************************************** STAKING POOLS ********************************************************************************
to pools_init [training_restart]
  set_pool_uniform_balance
  ;set_pool_uniform_stake
  ask pools [ set stake balance * 0.5 ]
  set_pool_uniform_fee
  ask pools [
    set shape "computer server"
    set color item who base-colors
    set size 3
    set name (word "Staking pool " who)
    set history table:make
    table:put history HISTORY_BALANCE_IDX (list balance)
    table:put history HISTORY_STAKE_IDX (list stake)
    table:put history HISTORY_GAIN_IDX [0]
    table:put history HISTORY_FEE_IDX (list fee)
    table:put history HISTORY_TX_COUNT_IDX [0]
    table:put history HISTORY_STATE_IDX (list STATE_BALANCE)
    table:put history HISTORY_ACTION_IDX (list ACTION_NOP)
    table:put BALANCES who balance
    table:put STAKES who stake
    set strategy STRATEGY_NONE
    set niceness -1
    set state STATE_BALANCE
    set tx_fee_running_mean 1
    set mngt_cost 0
    ;set total_reward 0
    ;set total_gain 0
      set total_stake 0
      set total_tx_count 0
    rt random 360
    fd random 100
  ]
  set_strategy_training
  if not training_restart [
    set SORTED_VALIDATORS sort-on [size] pools
    q_init_table
  ]
end

to pools_go
  ask pools [
    rt random 360
    fd 3
    set mngt_cost mngt_cost + random-float MANAGEMENT_COST
  ]
  collect_tx
end

to set_strategy_training
  ask pools with [member? who [0 1]] [ set strategy STRATEGY_NONE ]
  ask pools with [member? who [2 3 4 5]] [ set strategy STRATEGY_Q_LEARNING ]
  ask pools with [member? who [6 7 8 9]] [ set strategy STRATEGY_SARSA ]
end

to set_strategy_training_against_random_agents
  ask pools with [member? who [0 1 2 3 4 5 6 7 8]] [ set strategy STRATEGY_NONE ]
  ;ask pool 8 [ set strategy STRATEGY_Q_LEARNING ]
  ask pool 9 [ set strategy STRATEGY_SARSA ]
end


to set_strategy_training_differentiated
  ask pools with [member? who [0 1]] [ set strategy STRATEGY_NONE ]
  ask pools with [member? who [2 3]] [ set strategy STRATEGY_GREEDY ]
  ask pools with [member? who [4 5]] [ set strategy STRATEGY_IMITATION ]
  ask pools with [member? who [6 7]] [ set strategy STRATEGY_Q_LEARNING ]
  ask pools with [member? who [8 9]] [ set strategy STRATEGY_SARSA ]
end

to set_strategy_test
  ask pool 0 [ set strategy STRATEGY_GREEDY ]
  ask pool 1 [ set strategy STRATEGY_IMITATION ]
  ask pools with [member? who [2 3 4 5]] [ set strategy STRATEGY_Q_LEARNING ]
  ask pools with [member? who [6 7 8 9]] [ set strategy STRATEGY_SARSA ]
end

to set_strategy_sarsa_best
  ask pools with [member? who [0 1]] [ set strategy STRATEGY_NONE ]
  ask pools with [member? who [2 3]] [ set strategy STRATEGY_GREEDY ]
  ask pools with [member? who [4 5]] [ set strategy STRATEGY_IMITATION ]
  ask pools with [member? who [6 7 8 9]] [ set strategy STRATEGY_SARSA ]
end

to set_sarsa_best_q_table
  set_strategy_sarsa_best
  q_import_table "q_table-final.json"
  q_copy_best_table pool 8
end

to set_pool_uniform_balance
  ;let mu (MAX_SP_INIT_BALANCE - MIN_SP_INIT_BALANCE) / 2
  ;let b (MIN_SP_INIT_BALANCE + (random-normal mu MIN_SP_INIT_BALANCE) - MIN_SP_INIT_BALANCE)
  ask pools [ set balance MAX_SP_INIT_BALANCE ]
end

to set_pool_uniform_stake
  let s MIN_SP_INIT_STAKE + random-float (MAX_SP_INIT_BALANCE - MIN_SP_INIT_STAKE)
  ask pools [ set stake min list s balance * MAX_SP_STAKE_RATIO ]
end

to set_pool_uniform_fee
  ;let f MIN_FEE_PAYMENT + random-float (MAX_FEE - MIN_FEE_PAYMENT)
  let f abs random-normal 1 0.1
  ask pools [ set fee f ]
end

to collect_tx
  ask pools [
    ; self -> transaction ;; myself -> pool
    let fees []
    ask transactions in-radius 3 with [link-with myself = nobody] [
      set fees lput [fee] of self fees
      if [fee] of self >= [fee] of myself [ create-link-with myself ]
    ]
    foreach fees [ f -> set tx_fee_running_mean (tx_fee_running_mean ^ 0.8 * f ^ 0.2) ]
    ;foreach fees [ f -> set tx_fee_running_mean sqrt (tx_fee_running_mean * f) ]
  ]
end

to pools_update_history
  ask pools [
    let b table:get history HISTORY_BALANCE_IDX
    let g table:get history HISTORY_GAIN_IDX
    set g lput (balance - last b) g
    set b lput balance b
    let s table:get history HISTORY_STAKE_IDX
    set total_stake total_stake + last s
    set s lput stake s
    let f table:get history HISTORY_FEE_IDX
    set f lput fee f
    set total_gain total_gain + last g
    if length b > MEMORY [ set b sublist b (length b - MEMORY) (length b) ]
    if length g > MEMORY [ set g sublist g (length g - MEMORY) (length g) ]
    if length s > MEMORY [ set s sublist s (length s - MEMORY) (length s) ]
    if length f > MEMORY [ set f sublist f (length f - MEMORY) (length f) ]
    table:put history HISTORY_BALANCE_IDX b
    table:put history HISTORY_GAIN_IDX g
    table:put history HISTORY_STAKE_IDX s
    table:put history HISTORY_FEE_IDX f
    let t table:get history HISTORY_TX_COUNT_IDX
    set total_tx_count total_tx_count + last t
    set t lput 0 t
    if length t > MEMORY [ set t sublist t (length t - MEMORY) (length t) ]
    table:put history HISTORY_TX_COUNT_IDX t
    let state_ table:get history HISTORY_STATE_IDX
    set state_ lput state state_
    if state > STATE_BALANCE [ table:put STATE_GAIN_COUNTER who ((table:get STATE_GAIN_COUNTER who) + 1) ]
    if length state_ > MEMORY [ set state_ sublist state_ (length state_ - MEMORY) (length state_) ]
    table:put history HISTORY_STATE_IDX state_
    let action_ table:get history HISTORY_ACTION_IDX
    if length action_ > MEMORY [ set action_ sublist action_ (length action_ - MEMORY) (length action_) ]
    table:put history HISTORY_ACTION_IDX action_
  ]
end

to pool_update_tx_count [stake_pool n]
  ask stake_pool [
    let tx_count table:get history HISTORY_TX_COUNT_IDX
    set tx_count replace-item (length tx_count - 1) tx_count (last tx_count + n)
    table:put history HISTORY_TX_COUNT_IDX tx_count
  ]
end

to pool_update_action_history [stake_pool a]
  ask stake_pool [
    let acts table:get history HISTORY_ACTION_IDX
    set acts lput a acts
    table:put history HISTORY_ACTION_IDX acts
  ]
end

to-report clamp_simple_action [stake_pool action]
  let out true
  ask stake_pool [
    if (action = ACTION_STAKE_DROP and stake <= MIN_SP_INIT_STAKE)
     or  (action = ACTION_FEE_RAISE and fee >= MAX_FEE) [ set out false ]
  ]
  report out
end

to-report are_included [item1 item2]
  py:set "item1" item1
  py:set "item2" item2
  report py:runresult "item1 & item2 != 0"
end

to-report clamp_action [stake_pool action]
  ask stake_pool [
    ifelse stake - stake * DELTA_DROP < MIN_SP_INIT_STAKE and are_included action ACTION_STAKE_DROP [ set action action - ACTION_STAKE_DROP ]
    [ if stake + stake * DELTA_RAISE > balance * MAX_SP_STAKE_RATIO and are_included action ACTION_STAKE_RAISE [ set action action - ACTION_STAKE_RAISE ] ]
    ifelse fee + fee * DELTA_RAISE > MAX_FEE and are_included action ACTION_FEE_RAISE [ set action action - ACTION_FEE_RAISE ]
   [
      if fee - fee * DELTA_DROP < MIN_FEE and are_included action ACTION_FEE_DROP [ set action action - ACTION_FEE_DROP ]
   ]
  ]
  report max list ACTION_NOP action
end

to-report is_eop
  let out false
  let balance_lb max [balance] of pools * 0.2
  let stake_lb max [stake] of pools * 0.2
  let i 0
  while [ not out and i < N_SP ] [
    if ([strategy] of pool i) = STRATEGY_Q_LEARNING or ([strategy] of pool i) = STRATEGY_SARSA [
      ask pool i [
        if stake / balance >= MAX_SP_STAKE_RATIO
          or stake < MIN_SP_INIT_STAKE
  ;        or fee < MIN_FEE
  ;        or fee > MAX_FEE
          or balance <= balance_lb
          or stake < stake_lb
        [ set out true ]
      ]
    ]
    set i i + 1
  ]
  report out
end

to update_lr_epsilon
  set LR 1 / (1 + (EPOCH) ^ 0.7)
  set Q_EPSILON_ max list 0.01 (Q_EPSILON / (Q_EPSILON + EPOCH / 1e4))
end

to pools_execute_strategy
  set POOLS_AVG_STAKE mean [last table:get history HISTORY_STAKE_IDX] of pools
  ask pools [
    set state get_current_state self
    let next_action ACTION_NOP
    if strategy = STRATEGY_NONE [ set next_action one-of ACTIONS ]
    if strategy = STRATEGY_GREEDY [ set next_action get_action_greedy self ]
    if strategy = STRATEGY_IMITATION [ set next_action get_action_imitation self ]
    if strategy = STRATEGY_Q_LEARNING [
      ifelse Q_TRAINING [
        q_table_update self
        set next_action get_action_q self
      ]
      [ set next_action q_get_action_greedy_deployment self ]
    ]
    if strategy = STRATEGY_SARSA [
      ifelse Q_TRAINING [
        sarsa_q_table_update self
        set next_action table:get SARSA_NEXT_ACTION who
      ]
      [ set next_action q_get_action_greedy_deployment self ]
    ]
    if not Q_TRAINING [ set next_action clamp_action self next_action ]
    apply_action self next_action
  ]
  if Q_TRAINING [
    update_lr_epsilon
;    if is_eop [
;      reset_episode
;      print "Premature EOP"
;    ]
  ]
end
;; ******************************************************************************** TRANSACTIONS ********************************************************************************
to-report get_random_payment [snd]
  let ub [balance] of snd
  ifelse ub > MIN_PAYMENT [
    let mu ub / 100
    let sigma mu * 5
    report precision (min list ub max list MIN_PAYMENT (abs random-normal mu sigma)) DEFAULT_PRECISION
  ]
  [ report 0 ]
end

to-report get_random_fee [snd payment]
  report abs random-normal 1 0.3
end

to-report get_pl_fee [snd payment]
  let ub abs (([balance] of snd) - payment)
  let r 1 - random-float 1
  let m abs random-normal (0.95 * mean [fee] of pools) 0.1
  ;let m random-normal 1 0.1
  let out m * r ^ (-1 / (GAMMA_FEE - 1))
  report min list ub out
end

to process_smart_contract
  let txs_to_create []
  ask patches with [count users-here = 2] [
    let s one-of users-here
    let r one-of users-here with [who != [who] of s]
    if random-float 1 >= (1 - SMART_CONTRACT_SPAWN_RATE) [ set txs_to_create lput list s r txs_to_create ]
  ]
  foreach txs_to_create [ sr -> create_tx first sr last sr ]
end

to create_tx [snd rcv]
  if [balance] of snd > MIN_PAYMENT [
    create-transactions 1
    ask transactions with-max [who] [
      set shape "coin heads"
      set color yellow
      set xcor [xcor] of snd
      set ycor [ycor] of rcv
      set sender snd
      set receiver rcv
      let a get_random_payment snd
      ifelse a <= 0 [ die ]
      [
        let f get_pl_fee snd a
        set timestamp ticks
        ask snd [ set balance (balance - a - f) ]
        set amount a
        set fee f
      ]
    ]
  ]
end

to execute_tx [tx stake_pool]
  ;print (word "TIMESTAMP " ticks "\tpool " [who] of stake_pool "\tfee " fee)
  ask stake_pool [ set balance balance + [fee] of tx ]
  ask [receiver] of tx [ set balance balance + [amount] of tx ]
  set TX_FEE_HISTORY lput [fee] of tx TX_FEE_HISTORY
  if length TX_FEE_HISTORY > TX_PER_BLOCK [ set TX_FEE_HISTORY sublist TX_FEE_HISTORY 1 length TX_FEE_HISTORY ]
  ask tx [ die ]
end
;; ******************************************************************************** BLOCKCHAIN ********************************************************************************
to-report get_epoch
  report int floor (ticks / TICK_PER_EPOCH)
end

to-report choose_validator [ idx_sorted_candidates ]
  let sum_ 0
  foreach idx_sorted_candidates [ p -> ask p [ set sum_ sum_ + stake ] ]
  let cdf [0]
  (foreach idx_sorted_candidates [ p ->
    ask p [
      let val last cdf + (stake / sum_)
      set cdf lput val cdf
    ]
  ])
  set cdf sublist cdf 1 length cdf
  let idx 0
  let x random-float 0.998
  let done false
  while [ not done and idx < length idx_sorted_candidates ] [
    ifelse idx = (length idx_sorted_candidates - 1) or (x >= item idx cdf and x < item (idx + 1) cdf)  [ set done true ] [ set idx idx + 1 ]
  ]
  report item idx idx_sorted_candidates
end

to choose_validators
  let sorted []
  let niceness_score reverse range N_SP
  ifelse random-float 1 < EPSILON
  [ set sorted sort-on [size] pools ]
  [ set sorted sort-by [[p1 p2] -> [stake] of p1 > [stake] of p2] pools ]
  foreach range N_SP [ i -> ask item i sorted [set niceness item i niceness_score] ]
  set SORTED_VALIDATORS sorted
end

to build_block
  let built false
  let i 0
  while [i < N_SP and not built] [
    if [stake] of item i SORTED_VALIDATORS > MIN_SP_INIT_STAKE [
      set built try_build_block item i SORTED_VALIDATORS
    ]
    set i i + 1
  ]
  ;if built and i < 10 [ print "worksssssssssssssssssssssssssssssssssssssssss"]
end

to-report try_build_block [stake_pool]
  let built false
  ask stake_pool [
    let candidate_tx transactions with [link-with myself != nobody]
    if any? candidate_tx [
      let to_be_processed_tx min-n-of min list count candidate_tx TX_PER_BLOCK candidate_tx [timestamp]
      if (strategy = STRATEGY_Q_LEARNING or strategy = STRATEGY_SARSA) and Q_TRAINING [
        let max_reward sum [fee] of max-n-of min list count candidate_tx TX_PER_BLOCK candidate_tx [fee]
        set delta_reward sum [fee] of to_be_processed_tx / max_reward
      ]
      set built true
      set balance balance + BLOCK_REWARD
      set CURRENT_REWARD CURRENT_REWARD + BLOCK_REWARD - mngt_cost
      pool_update_tx_count self count to_be_processed_tx
      ask other pools [ pool_update_tx_count self 0 ]
      ask to_be_processed_tx [
        set CURRENT_REWARD CURRENT_REWARD + [fee] of self
        execute_tx self myself
      ]
      set AVG_TX_FEE_HISTORY (reduce [[x y] -> x * y] TX_FEE_HISTORY) ^ (1 / length TX_FEE_HISTORY)
    ]
  ]
  report built
end

to replace_by_fee_last_n [n]
  let candidate_tx sort-on [fee] transactions with [fee < mean [fee] of pools]
  set candidate_tx sublist candidate_tx 0 min list n length candidate_tx
  (foreach candidate_tx [ tx ->
    if [balance] of [sender] of tx >= [fee] of tx [ ask [sender] of tx [ set balance balance - [fee] of tx ] ]
    ask tx [ set fee fee * 2]
  ])
  ;if not empty? candidate_tx [ print "Replace-by-fee happened" ]
end
;; ******************************************************************************** STRATEGIES ********************************************************************************
to-report strategy_int2str [idx]
  ifelse idx = STRATEGY_NONE [ report "random" ]
  [ ifelse idx = STRATEGY_GREEDY [ report "greedy" ]
    [
      ifelse idx = STRATEGY_IMITATION [ report "imitation" ]
      [
        ifelse idx = STRATEGY_Q_LEARNING [ report "q-learning" ]
        [
           if idx = STRATEGY_SARSA [ report "sarsa" ]
        ]
      ]
    ]
  ]
end

to apply_action [ stake_pool a]
  ask stake_pool [
    let new_stake NONE
    let new_fee NONE
    if a = ACTION_STAKE_RAISE_FEE_RAISE [
      set new_stake max list 0 min list (balance * MAX_SP_STAKE_RATIO) (stake + stake * DELTA_RAISE)
      set new_fee fee + fee * DELTA_RAISE
    ]
    if a = ACTION_STAKE_RAISE_FEE_DROP [
      set new_stake max list 0 min list (balance * MAX_SP_STAKE_RATIO) (stake + stake * DELTA_RAISE)
      set new_fee max list 0 (fee - fee * DELTA_DROP)
    ]
    if a = ACTION_STAKE_DROP_FEE_RAISE [
      set new_stake max list 0 min list (balance * MAX_SP_STAKE_RATIO) max list 0 (stake - stake * DELTA_DROP)
      set new_fee fee + fee * DELTA_RAISE
    ]
    if a = ACTION_STAKE_DROP_FEE_DROP [
      set new_stake max list 0 min list (balance * MAX_SP_STAKE_RATIO) max list 0 (stake - stake * DELTA_DROP)
      set new_fee max list 0 (fee - fee * DELTA_DROP)
    ]
    if a = ACTION_STAKE_RAISE [
      set new_stake max list 0 min list (balance * MAX_SP_STAKE_RATIO) (stake + stake * DELTA_RAISE)
    ]
    if a = ACTION_STAKE_DROP [
      set new_stake max list 0 min list (balance * MAX_SP_STAKE_RATIO) max list 0 (stake - stake * DELTA_DROP)
    ]
    if a = ACTION_FEE_RAISE [
      set new_fee fee + fee * DELTA_RAISE
    ]
    if a = ACTION_FEE_DROP [
      set new_fee fee - fee * DELTA_DROP
    ]
    if new_stake != NONE [ set stake max list 0 new_stake ]
    if new_fee != NONE [ set fee new_fee ]
  ]
  pool_update_action_history self a
end

to-report get_current_state [stake_pool]
  let out STATE_BALANCE
  ask stake_pool [
    if not empty? table:keys history [
      let gain balance - last table:get history HISTORY_BALANCE_IDX
      ifelse gain > 0 [ set out out + STATE_GAIN ] [ set out out + STATE_LOSS ]
      ifelse stake > 1.01 * POOLS_AVG_STAKE [ set out out + STATE_STAKE_H ] [ if stake < 0.99 * POOLS_AVG_STAKE  [ set out out + STATE_STAKE_L ] ]
      ifelse fee > tx_fee_running_mean [ set out out + STATE_FEE_H ] [ if fee < tx_fee_running_mean [ set out out + STATE_FEE_L ] ]
    ;print (word "current state  " out " " stake_pool " " gain)
    ]
  ]
  report out
end

to-report get_max_item [table_counter]
  report first first sort-by [[kv1 kv2] -> last kv1 >= last kv2] table:to-list table_counter
end

to-report get_action_greedy [stake_pool]
  let out ACTION_NOP
  ask stake_pool [
    let gain balance - last table:get history HISTORY_BALANCE_IDX
    ifelse stake > 1.1 * POOLS_AVG_STAKE and gain > LOSS_THRESHOLD [ set out out + ACTION_STAKE_DROP ]
    [
      ifelse stake < 0.9 * POOLS_AVG_STAKE and gain <  LOSS_THRESHOLD [ set out out + ACTION_STAKE_RAISE ] [
        ifelse random-float 1 < 0.5 [ set out out + ACTION_STAKE_RAISE ] [ set out out + ACTION_STAKE_DROP ]
      ]
    ]
    ifelse fee < tx_fee_running_mean [ set out out + ACTION_FEE_RAISE ]
    [ set out out + ACTION_FEE_DROP ]
  ]
  report out
end

to-report get_best_pool
  report first sort-by [[p1 p2] ->
    mean table:get [history] of p1 HISTORY_GAIN_IDX > mean table:get [history] of p2 HISTORY_GAIN_IDX] pools
end

to-report get_action_imitation [stake_pool]
  let out ACTION_NOP
  ifelse random-float 1 < EPSILON_IMITATION [ set out one-of ACTIONS ]
  [
    let best_pool get_best_pool
    let counter table:from-list (map [[k v] -> list k v] ACTIONS_SIMPLE n-values length ACTIONS_SIMPLE [0])
    ask best_pool [
      let acts table:counts table:get history HISTORY_ACTION_IDX
      (foreach table:keys acts [ key ->
        ifelse table:has-key? counter key [ table:put counter key ((table:get counter key) + 1) ]
        [
          py:set "action_complex" key
          (foreach ACTIONS_SIMPLE [a ->
            if a != key [
              py:set "other_action" a
              if py:runresult "(action_complex & other_action) != 0" [
                table:put counter a ((table:get counter a) + 1)
                ;iprint (word "Found " a " to be included in " key)
              ]
            ]
          ])
        ]
      ])
    ]
    let counter_list map [xx -> first xx] sort-by [[x y] -> last x > last y] table:to-list counter
    set out first counter_list
    let a2 item 1 counter_list
    if member? (out + a2) ACTIONS [ set out out + a2 ]
    ask stake_pool [
      if are_included out ACTION_FEE_RAISE and fee >= 1.1 * tx_fee_running_mean [ set out out - ACTION_FEE_RAISE ]
      if are_included out ACTION_STAKE_RAISE and stake >= 1.1 * POOLS_AVG_STAKE [ set out out - ACTION_STAKE_RAISE ]
    ]
  ]
  report out
end

;; ******************************************************************************** Q_LEARNING ********************************************************************************
to q_init_table
  ask pools with [strategy = STRATEGY_Q_LEARNING or strategy = STRATEGY_SARSA] [
    set q_table table:make
    (foreach STATES [ s ->
      let qt_act table:make
      ;foreach ACTIONS [ a -> table:put qt_act a (-1 + random-float 2) ]
      foreach ACTIONS [ a -> table:put qt_act a 0 ]
      table:put q_table s qt_act
    ])
    if strategy = STRATEGY_SARSA [ table:put SARSA_NEXT_ACTION who one-of ACTIONS ]
  ]
end

to q_export_table [filename]
  let q_pools []
  ask pools with [strategy = STRATEGY_Q_LEARNING or strategy = STRATEGY_SARSA] [ set q_pools lput who q_pools ]
  set q_pools sort-by [[p1 p2] -> [who] of pool p1 < [who] of pool p2] q_pools
  if not empty? q_pools [
    carefully [ file-delete filename ] [ print (word "File " filename " doesn't exist yet") ]
    file-open filename
    file-print "{"
    let max_q_idx max q_pools
    (foreach q_pools [i ->
      ask pool i [
        file-print (word "\t\"" i "\": {\n" )
        (foreach table:to-list q_table range length STATES [[qs_pair is] ->
          file-print (word "\t\t\"" (first qs_pair) "\": {")
          (foreach table:to-list last qs_pair range length ACTIONS [[qa_pair ia] ->
            let a_str (word "\t\t\t\"" (first qa_pair) "\": " (last qa_pair))
            if ia < (length ACTIONS - 1) [ set a_str (word a_str ",") ]
            file-print a_str
          ])
          let s_str "\t\t}"
          if is < (length STATES - 1) [ set s_str (word s_str ",") ]
          file-print s_str
        ])
      ]
      let i_str "\t}"
      if i < max_q_idx [ set i_str (word i_str ",") ]
      file-print i_str
    ])
    file-print "}"
    file-close
  ]
end


to q_import_table [filename]
  let tmp table:from-json-file filename
  (foreach table:to-list tmp [p ->
    (foreach table:to-list last p [pp ->
      (foreach table:to-list last pp [ppp ->
        let k read-from-string first ppp
        table:put last pp k last ppp
        table:remove last pp first ppp
      ])
      let k read-from-string first pp
      table:put last p k last pp
      table:remove last p first pp
    ])
    let k read-from-string first p
    table:put tmp k last p
    table:remove tmp first p
    ask pool k [ set q_table table:get tmp k ]
  ])
end

to q_copy_best_table [stake_pool]
  ask pools with [who != [who] of stake_pool] [
    set q_table [q_table] of stake_pool
  ]
end

to-report get_action_q_greedy [stake_pool]
  let action ACTION_NOP
  ask stake_pool [
    let kvs table:to-list table:get q_table state
    set kvs sort-by [[kv1 kv2] -> last kv1 > last kv2] kvs
    set action first first kvs
  ]
  report action
end

to-report get_action_q [stake_pool]
  ifelse random 1 < Q_EPSILON_ [ report one-of ACTIONS ]
  [ report get_action_q_greedy stake_pool ]
end

to-report is_action_included [a1 a2]
  py:set "a1" a1
  py:set "a2" a2
  report py:runresult "a1 & a2 != 0"
end

to-report q_get_reward [stake_pool]
  let r -0.01
  ask stake_pool [
    ;print (word "BALANCE " balance " STAKE " stake " S_B ratio " (stake / balance))
    ifelse balance <= MIN_SP_INIT_STAKE
      or stake / balance >= MAX_SP_STAKE_RATIO
      or stake < MIN_SP_INIT_STAKE
      or fee < MIN_FEE
      or fee > MAX_FEE
    [ set r EOP_REWARD ]
    [
      let gain balance - last table:get history HISTORY_BALANCE_IDX
      let fee_rw 1 - abs (fee - tx_fee_running_mean) / max list fee tx_fee_running_mean
      ;print (word "FEE_RW: " fee_rw "   GAIN_RW: " ((gain * 100) / stake))
      let gain_rw 0
      ifelse gain > 0 [ set gain_rw gain / stake * 100 ] [ set gain_rw gain / (MANAGEMENT_COST * TICK_PER_EPOCH) ]
      set r gain_rw
      if (strategy = STRATEGY_Q_LEARNING and (
        (are_included state STATE_FEE_L and not are_included get_action_q_greedy self ACTION_FEE_RAISE)
        or (are_included state STATE_FEE_H and not are_included get_action_q_greedy self ACTION_FEE_DROP)
      ))
      or (strategy = STRATEGY_SARSA and (
          (are_included state STATE_FEE_L and not are_included sarsa_get_action_greedy self ACTION_FEE_RAISE)
          or (are_included state STATE_FEE_H and not are_included sarsa_get_action_greedy self ACTION_FEE_DROP)
        ))
      [ set r r - 1 ]
      set r max list -1 r
      set total_reward total_reward + r
      set delta_reward 0
    ]
  ]
  report r
end

to q_table_update [stake_pool]
  ask stake_pool [
    let current_action last table:get history HISTORY_ACTION_IDX
    let current_state last table:get history HISTORY_STATE_IDX
    let q_old table:get (table:get q_table current_state) current_action
    let q_opt table:get (table:get q_table state) get_action_q_greedy self
    let r q_get_reward self
    let q_new q_old + LR * (r + DISCOUNT * q_opt - q_old)
    table:put (table:get q_table current_state) current_action q_new
    ;print (word "[" who self "] Q updates! Q_OLD: " q_old " Q_NEW: " q_new " CURRENT_STATE: " state " CURRENT_ACTION: " current_action " REWARD: " r)
  ]
end

to-report q_get_action_greedy_deployment [stake_pool]
  ifelse random-float 1 < 0.05 [ report one-of ACTIONS ]
  [ report get_action_q_greedy stake_pool ]
end
;; ******************************************************************************** SARSA ********************************************************************************
to-report sarsa_get_action_greedy [stake_pool]
  ifelse random 1 < Q_EPSILON_ [ report one-of ACTIONS ]
  [ report get_action_greedy stake_pool ]
end

to sarsa_q_table_update [stake_pool]
  ask stake_pool [
    let current_action last table:get history HISTORY_ACTION_IDX
    let current_state last table:get history HISTORY_STATE_IDX
    let q_old table:get (table:get q_table current_state) current_action
    let action sarsa_get_action_greedy self
    let q_next table:get (table:get q_table state) action
    let r q_get_reward self
    let q_new q_old + LR * (r + DISCOUNT * q_next - q_old)
    table:put (table:get q_table current_state) current_action q_new
    table:put SARSA_NEXT_ACTION who action
    ;print (word "[" who self "] Q updates! Q_OLD: " q_old " Q_NEW: " q_new " CURRENT_STATE: " state " CURRENT_ACTION: " current_action " REWARD: " r " NEXT ACTION " action)
  ]
end

;; ******************************************************************************** PLOTS ********************************************************************************
to update-sp-balance-histogram
  set-current-plot "Staking pools total balance"
  clear-plot
  (foreach range N_SP [ i ->
    if [balance] of pool i > 0 [
      create-temporary-plot-pen [name] of pool i
      set-plot-pen-mode 1
      let step 0.01
      let scaled_balance ((table:get BALANCES i) / 1000)
      let scaled_stake ((table:get STAKES i) / 1000)
      set-plot-pen-color [color] of pool i
      foreach (range scaled_stake scaled_balance step) [ y -> plotxy i y ]
      set-plot-pen-color black
      plotxy i scaled_balance
      set-plot-pen-color [color] of pool i
    ]
  ])
  create-temporary-plot-pen "in-stake amount"
  set-plot-pen-color white
end

to update-sp-fee-rate
  set-current-plot "Staking pools minimum fee"
  clear-plot
  ;set-plot-x-range 0 N_SP + 1
  set-plot-y-range 0 MAX_FEE
  ask pools [
    create-temporary-plot-pen name
    set-plot-pen-color color
    set-plot-pen-mode 1
    foreach (range 0.0 fee (MAX_FEE / 200)) [ y -> plotxy who y]
    set-plot-pen-color black
    plotxy who fee
    set-plot-pen-color color
  ]
end

to update_strategy_gain
  set-current-plot "Strategies avg gain"
  let values []
  if ticks = 0 [ clear-plot ]
  if ticks mod TICK_PER_EPOCH = 0 [
    (foreach STRATEGIES [ s ->
      let current_strategy_gain []
      ask pools with [strategy = s] [ set current_strategy_gain lput (last table:get history HISTORY_GAIN_IDX) current_strategy_gain ]
      let current_strategy_avg_gain 0
      if not empty? current_strategy_gain [
        set current_strategy_avg_gain mean current_strategy_gain
        set values lput current_strategy_avg_gain values
      ]
      let max_y current_strategy_avg_gain + 1
      if max_y > max_normalized_gain_y [ set max_normalized_gain_y ceiling max_y ]
      let min_y current_strategy_avg_gain - 1
      if min_y < min_normalized_gain_y [ set min_normalized_gain_y floor min_y ]
      set-plot-y-range min_normalized_gain_y max_normalized_gain_y
      ;set-plot-x-range 0 max list 2 get_epoch
      create-temporary-plot-pen strategy_int2str s
      set-plot-pen-color item s STRATEGY_COLORS
      set-plot-pen-mode 0
      plot current_strategy_avg_gain
    ])
;    let max_y ceiling max values + 50
;    let min_y floor min values - 10
;    set-plot-y-range min_y max_y
    set-plot-x-range max list 0 (get_epoch - 50) max list 2 get_epoch
  ]
end

to-report get_gain_stake_ratio [stake_pool]
  let ratio 0
  ask stake_pool [
    let gain last table:get history HISTORY_GAIN_IDX
    set ratio gain / max list 1e-3 stake
  ]
  report ratio
end

to update_strategy_gain_stake_ratio
  set-current-plot "Strategies gain-stake ratio (%)"
  if ticks = 0 [ clear-plot ]
  if ticks mod TICK_PER_EPOCH = 0 [
    (foreach STRATEGIES [ s ->
      let current_strategy_ratio []
      ask pools with [strategy = s] [ set current_strategy_ratio lput (get_gain_stake_ratio self * 100) current_strategy_ratio ]
      let current_strategy_avg_ratio  0
      if not empty? current_strategy_ratio [ set current_strategy_avg_ratio mean current_strategy_ratio ]
      let current_min_max item s gs_ratio_min_max
      if current_strategy_avg_ratio < first current_min_max [ set current_min_max replace-item 0 current_min_max current_strategy_avg_ratio ]
      if current_strategy_avg_ratio > last current_min_max [ set current_min_max replace-item 1 current_min_max current_strategy_avg_ratio ]
      set gs_ratio_min_max replace-item s gs_ratio_min_max current_min_max
      let val (current_strategy_avg_ratio - first current_min_max) / (last current_min_max - first current_min_max)
      set-plot-x-range 0 max list 2 get_epoch
      set-plot-y-range min_gain_stake_ratio_y max_gain_stake_ratio_y
      create-temporary-plot-pen strategy_int2str s
      set-plot-pen-color item s STRATEGY_COLORS
      set-plot-pen-mode 0
      plot val
    ])
    set-plot-y-range 0 1
    set-plot-x-range max list 0 (get_epoch - 50) max list 2 get_epoch
  ]
end

to update_strategy_avg_n_tx
  set-current-plot "Strategies avg # executed txs"
  let values []
  if ticks = 0 [ clear-plot ]
  if ticks mod TICK_PER_EPOCH = 0 [
    (foreach STRATEGIES [ s ->
      let current_coll_tx []
      ask pools with [strategy = s] [ set current_coll_tx lput (last table:get history HISTORY_TX_COUNT_IDX) current_coll_tx ]
      let current_coll_tx_avg  0
      if not empty? current_coll_tx [
        set current_coll_tx_avg mean current_coll_tx
        set values lput current_coll_tx_avg values
      ]
;      let max_y current_coll_tx_avg + 0.5
;      if max_y > max_current_coll_tx_avg_y [ set max_current_coll_tx_avg_y ceiling max_y ]
;      let min_y current_coll_tx_avg - 0.5
;      if min_y < min_current_coll_tx_avg_y [ set min_current_coll_tx_avg_y floor max_y ]
;      set-plot-x-range 0 max list 2 get_epoch
;      set-plot-y-range min_current_coll_tx_avg_y max_current_coll_tx_avg_y
      create-temporary-plot-pen strategy_int2str s
      set-plot-pen-color item s STRATEGY_COLORS
      set-plot-pen-mode 0
      plot current_coll_tx_avg
    ])
    let max_y ceiling max values + 2
    let min_y floor min values - 0.5
    set-plot-y-range min_y max_y
    set-plot-x-range max list 0 (get_epoch - 50) max list 2 get_epoch
  ]
end

to update_strategy_avg_state_gain
  set-current-plot "Strategies avg # state_gain reached"
  if ticks = 0 [ clear-plot ]
  if ticks mod TICK_PER_EPOCH = 0 [
    let values []
    (foreach STRATEGIES [ s ->
      let current_state_gain_count []
      ask pools with [strategy = s] [ set current_state_gain_count lput (table:get STATE_GAIN_COUNTER who) current_state_gain_count ]
      let current_state_gain_count_avg  0
      if not empty? current_state_gain_count [
        set current_state_gain_count_avg mean current_state_gain_count
        set values lput current_state_gain_count_avg values
      ]
;      let max_y current_state_gain_count_avg + 10
;      if max_y > max_current_state_gain_count_avg_y [ set max_current_state_gain_count_avg_y ceiling max_y ]
;      let min_y current_state_gain_count_avg
;      if min_y < min_current_state_gain_count_avg_y [ set min_current_state_gain_count_avg_y floor max_y ]
;      set-plot-y-range min_current_state_gain_count_avg_y max_current_state_gain_count_avg_y
      create-temporary-plot-pen strategy_int2str s
      set-plot-pen-color item s STRATEGY_COLORS
      set-plot-pen-mode 0
      plot current_state_gain_count_avg
    ])
    let max_y ceiling max values + 2
    let min_y floor min values - 2
    set-plot-y-range min_y max_y
    set-plot-x-range max list 0 (get_epoch - 50) max list 2 (get_epoch + 10)
  ]
end

to update_strategy_total_gain
  set-current-plot "Strategies total gain"
  ifelse ticks = 0 [ clear-plot ]
  [
    if ticks mod EPISODE_LENGTH = 0 [
    (foreach STRATEGIES [ s ->
      let current_total_gain []
      ask pools with [strategy = s] [
        set current_total_gain lput total_gain current_total_gain
        set total_gain 0
      ]
      let current_total_gain_avg  0
      if not empty? current_total_gain [ set current_total_gain_avg mean current_total_gain ]
      create-temporary-plot-pen strategy_int2str s
      set-plot-pen-color item s STRATEGY_COLORS
      set-plot-pen-mode 0
      plot current_total_gain_avg
    ])
   ]
  ]
end


to update_users_balance
  set-current-plot "Users balance"
  clear-plot
  create-temporary-plot-pen "users_balance_pen"
  set-plot-pen-color black
  set-plot-pen-mode 1
  set-plot-x-range N_SP N_SP + count users
  ask users [
    foreach range balance [ y -> plotxy who y]
    set-plot-pen-color green
    plotxy who balance
    set-plot-pen-color black
  ]
end


to update_train_avg_reward
  set-current-plot "Train average reward"
  let values []
  ifelse ticks = 0 [ clear-plot ]
  [
    if ticks mod EPISODE_LENGTH = 0 [
    ask pools with [strategy = STRATEGY_Q_LEARNING or strategy = STRATEGY_SARSA] [
        let avg_rw total_reward / EPISODE_LENGTH * TICK_PER_EPOCH
        set values lput avg_rw values
        create-temporary-plot-pen name
        set-plot-pen-color color
        plot avg_rw
        set-plot-pen-mode 0
        set total_reward 0
    ]
    set-plot-y-range precision (-1.5 * abs min values) DEFAULT_PRECISION precision (1.5 * abs max values) DEFAULT_PRECISION
   ]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
228
10
769
552
-1
-1
13.0
1
10
1
1
1
0
1
1
1
-20
20
-20
20
0
0
1
ticks
30.0

SLIDER
9
186
181
219
N_TURTLES
N_TURTLES
0
200
120.0
1
1
NIL
HORIZONTAL

SLIDER
10
231
182
264
N_SP
N_SP
1
10
10.0
1
1
NIL
HORIZONTAL

BUTTON
12
19
86
52
Setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
8
73
71
106
Go
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
8
116
71
149
Go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
772
226
1351
459
Staking pools total balance
NIL
[10^3]
0.0
0.0
0.0
0.0
true
true
"set-plot-x-range 0 N_SP\nset-plot-y-range 0 (MAX_SP_INIT_BALANCE / 1000)\nset-histogram-num-bars count pools" "update-sp-balance-histogram"
PENS

SLIDER
11
270
183
303
TX_PER_BLOCK
TX_PER_BLOCK
5
50
15.0
1
1
NIL
HORIZONTAL

SLIDER
8
567
297
600
SMART_CONTRACT_SPAWN_RATE
SMART_CONTRACT_SPAWN_RATE
1e-2
1
0.75
1e-2
1
NIL
HORIZONTAL

SLIDER
10
313
185
346
TICK_PER_EPOCH
TICK_PER_EPOCH
1
50
10.0
1
1
NIL
HORIZONTAL

PLOT
773
15
1093
222
Staking pools minimum fee
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" "update-sp-fee-rate\n"
PENS

MONITOR
79
94
220
155
TXS IN MEMPOOL
count transactions
0
1
15

PLOT
1097
10
1510
224
Strategies avg gain
NIL
NIL
0.0
10.0
0.0
10.0
false
false
"" "update_strategy_gain"
PENS

MONITOR
101
17
217
78
EPOCH
EPOCH
0
1
15

PLOT
1362
227
1881
462
Strategies gain-stake ratio (%)
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" "update_strategy_gain_stake_ratio"
PENS

PLOT
1518
10
1879
222
Strategies avg # executed txs
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" "update_strategy_avg_n_tx"
PENS

SLIDER
10
421
182
454
EPSILON
EPSILON
0
1
0.15
0.01
1
NIL
HORIZONTAL

SWITCH
9
513
148
546
Q_TRAINING
Q_TRAINING
1
1
-1000

PLOT
775
466
1132
650
Strategies total gain
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" "update_strategy_total_gain"
PENS

MONITOR
15
363
98
408
NIL
count links
17
1
11

SLIDER
11
465
183
498
Q_EPSILON
Q_EPSILON
0
0.99
0.99
0.01
1
NIL
HORIZONTAL

PLOT
0
681
375
801
Train average reward
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" "update_train_avg_reward"
PENS

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

coin heads
false
0
Circle -7500403 true true 15 15 270
Circle -16777216 false false 22 21 256
Line -16777216 false 165 180 192 196
Line -16777216 false 42 140 83 140
Line -16777216 false 37 151 91 151
Line -16777216 false 218 167 265 167
Polygon -16777216 false false 148 265 75 229 86 207 113 191 120 175 109 162 109 136 86 124 137 96 176 93 210 108 222 125 203 157 204 174 190 191 232 230
Polygon -16777216 false false 212 142 182 128 154 132 140 152 149 162 144 182 167 204 187 206 193 193 190 189 202 174 193 158 202 175 204 158
Line -16777216 false 164 154 182 152
Line -16777216 false 193 152 202 153
Polygon -16777216 false false 60 75 75 90 90 75 105 75 90 45 105 45 120 60 135 60 135 45 120 45 105 45 135 30 165 30 195 45 210 60 225 75 240 75 225 75 210 90 225 75 225 60 210 60 195 75 210 60 195 45 180 45 180 60 180 45 165 60 150 60 150 45 165 45 150 45 150 30 135 30 120 60 105 75

computer server
false
0
Rectangle -7500403 true true 75 30 225 270
Line -16777216 false 210 30 210 195
Line -16777216 false 90 30 90 195
Line -16777216 false 90 195 210 195
Rectangle -10899396 true false 184 34 200 40
Rectangle -10899396 true false 184 47 200 53
Rectangle -10899396 true false 184 63 200 69
Line -16777216 false 90 210 90 255
Line -16777216 false 105 210 105 255
Line -16777216 false 120 210 120 255
Line -16777216 false 135 210 135 255
Line -16777216 false 165 210 165 255
Line -16777216 false 180 210 180 255
Line -16777216 false 195 210 195 255
Line -16777216 false 210 210 210 255
Rectangle -7500403 true true 84 232 219 236
Rectangle -16777216 false false 101 172 112 184

computer workstation
false
0
Rectangle -7500403 true true 60 45 240 180
Polygon -7500403 true true 90 180 105 195 135 195 135 210 165 210 165 195 195 195 210 180
Rectangle -16777216 true false 75 60 225 165
Rectangle -7500403 true true 45 210 255 255
Rectangle -10899396 true false 249 223 237 217
Line -16777216 false 60 225 120 225

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
