import ApiClient from './ApiClient';

class RoutingTypes extends ApiClient {
  constructor() {
    super('routing_types', { accountScoped: true });
  }
}

export default new RoutingTypes();
