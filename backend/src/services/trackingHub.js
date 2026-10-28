const EventEmitter = require('events');

class TrackingHub extends EventEmitter {
  constructor() {
    super();
    this.setMaxListeners(500);
  }

  channelName(orderId) {
    return `order_tracking:${String(orderId)}`;
  }

  subscribe(orderId, listener) {
    const channel = this.channelName(orderId);
    this.on(channel, listener);
    return () => {
      this.removeListener(channel, listener);
    };
  }

  broadcast(orderId, payload) {
    const channel = this.channelName(orderId);
    this.emit(channel, payload);
  }
}

module.exports = new TrackingHub();
