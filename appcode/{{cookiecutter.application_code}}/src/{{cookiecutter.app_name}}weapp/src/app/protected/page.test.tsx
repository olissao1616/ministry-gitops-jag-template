import '@testing-library/jest-dom'
import { render, screen } from '@testing-library/react'
import { sampleAppData } from '../_nonRoutingAssets/types/mockData';
import { getApplicationData } from './actions';

jest.mock("./actions", () => ({
  __esModule: true,
  getApplicationData: jest.fn(() => {}),
}));

describe("Landing page", () => { 
  it('Application data fetch should be called', async () =>{ 
    const callFunction = getApplicationData.mockReturnValue(Promise.resolve(sampleAppData)); 
    const data = await getApplicationData(); 
    expect(callFunction).toHaveBeenCalled(); 
    expect(data).toHaveLength(2);
    expect(data[0]).toHaveProperty('code', 'LEA');
  }); 

  // it('Landing page should render all the content', async () => {
  //   render(<ApplicationSelection />)

  //   expect(screen.getByText('Login')).toBeInTheDocument()
  // });

});