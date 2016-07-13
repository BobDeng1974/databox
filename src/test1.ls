require! {
  fs
  readline
  request
  \stats-lite
  './container-manager.ls': con-man
}

const server-port = process.env.PORT or 8080

running-containers = []

aggregate-stats = do
  gather-stat = (info) ->
    resolve, reject <-! new Promise!

    result <- con-man.get-container-stats-stream info.name .then

    data = []

    rl = readline.create-interface input: result.stream
      ..on \line !->
        it = JSON.parse it

        # Sum across all network interfaces
        rx-sum = 0
        tx-sum = 0
        for name, network of it.networks
          rx-sum += network.rx_bytes
          tx-sum += network.tx_bytes

        row =
          time: it.read
          type: info.type
          rx:   rx-sum
          tx:   tx-sum
          mem:  it.memory_stats.usage

        cpu-delta = it.cpu_stats.cpu_usage.total_usage - it.precpu_stats.cpu_usage.total_usage
        system-delta = it.cpu_stats.system_cpu_usage - it.precpu_stats.system_cpu_usage
        row.cpu = (cpu-delta / system-delta) * it.cpu_stats.cpu_usage.percpu_usage.length

        data.push row

        if data.length > 10
          rl.close!
          delete data.time
          resolve data

  ->
    resolve, reject <-! new Promise!
    console.log 'Aggregating stats'

    gather-stats =
      running-containers
      |> (.map gather-stat)
      |> Promise.all

    gather-stats
      .then (stats) -> [].concat.apply [] stats
      .then resolve
      .catch reject

trigger-scan = (driver-port) ->
  resolve, reject <-! new Promise!
  console.log 'Triggering mock driver store scan'
  # TODO: Remove dirty hack to wait for the store to set up
  <-! set-timeout _, 2000
  err, res, body <-! request "http://localhost:#driver-port/scan"
  if err?
    reject err
    return
  resolve body

run-test = do ->
  out = fs.create-write-stream 'data/test-1.csv'
    ..write 'stores,type,rx,tx,mem,cpu\n'

  (store-count, store-count-max, driver-port) ->
    resolve, reject <-! new Promise!
    if store-count >= store-count-max
      resolve!
      return

    running-containers.push name: "databox-store-mock-#store-count" type: \store
    launch-store = "databox-store-mock-#store-count"
      |> -> con-man.launch-container 'amar.io:5000/databox-store-mock:latest', it, [ "HOSTNAME=#it" ]

    launch-store
      .then -> trigger-scan driver-port
      .then -> aggregate-stats!
      .then (stats) ->
        for stat in stats
          out.write "#{store-count + 1},#{stat.type},#{stat.rx},#{stat.tx},#{stat.mem},#{stat.cpu}\n"
      .then -> run-test ++store-count, store-count-max, driver-port
      .then resolve
      .catch reject

console.log 'Establishing communication with Docker daemon'
con-man.connect!
  .then ->
    # Kill any already running Databox containers
    console.log 'Killing any already running Databox containers'
    con-man.kill-all!
  .then ->
    # Create networks if they do not already exist
    console.log 'Checking driver and app networks'
    con-man.init-networks!
  .then ->
    # Launch Arbiter
    console.log 'Launching Arbiter container'
    running-containers.push name: \arbiter type: \arbiter
    con-man.launch-arbiter!
  .then ->
    # Launch mock driver
    console.log 'Launching mock driver'
    running-containers.push name: \databox-driver-mock type: \driver
    con-man.launch-container 'amar.io:5000/databox-driver-mock:latest'
  .then (result) ->
    # TODO: Reject and catch
    throw new Error result.err if result.err?
    run-test 0 100 result.port
  .then ->
    console.log 'Done'
  .catch !-> console.log it

/*
# Clean up on exit
clean-up = !->
  console.log 'Cleaning up'
  # TODO: Find a way to do this
  # con-man.kill-all ->

process
  ..on \exit clean-up
  ..on \SIGINT clean-up
  #..on \uncaughtException !->
*/
