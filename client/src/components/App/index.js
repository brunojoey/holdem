import React from 'react';
import {
  BrowserRouter as Router,
  Switch,
  Route
}from 'react-router-dom';
import { Provider, APIProvider } from '../../models';
import {
  // Header,
  Fatal,
  Footer,
  Poker
} from '..';
import styles from './index.module.css';
import './index.css';

function App() {
  return (
    <Provider>
      <div className={ styles.container }>
        <Router>
          { /* <Header /> */ }
          <main className={ styles.content }>
            <Switch>
              <Route path="/error">
                <Fatal />
              </Route>
              <Route>
                <APIProvider>
                  <Poker />
                </APIProvider>
              </Route>
            </Switch>
          </main>
          <Footer />
        </Router>
      </div>
    </Provider>
  );
}

export default App;
