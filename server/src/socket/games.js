const { Games } = require('../models');
const events = require('./events');

function onStart(sockets) {
  Games.listener.listen(async (id) => {
    const exists = await Games.exists({ id });

    if (!exists) {
      sockets.emit(
        events.games.itemRemove,
        id,
      );
    } else {
      const game = await Games.abridged({ id });

      sockets.emit(
        events.games.itemUpdate,
        game,
      );
    }
  });
}

function onConnect(socket) {
  socket.on(
    events.games.request,
    async () => {
      const games = await Games.list();
      socket.emit(
        events.games.list,
        games,
      );
    },
  );
}

function onDisconnect() {}

module.exports = {
  onStart,
  onConnect,
  onDisconnect,
};
