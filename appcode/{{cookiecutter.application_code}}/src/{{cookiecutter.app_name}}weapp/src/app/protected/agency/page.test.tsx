import '@testing-library/jest-dom'
import { render, screen } from '@testing-library/react'
import { sampleAgencyData } from '@/app/_nonRoutingAssets/types/mockData';
import { getAgencyData } from './actions';

jest.mock("./actions", () => ({
  __esModule: true,
  getAgencyData: jest.fn(() => {}),
}));

describe("Agency select page", () => { 
  it('Agency data fetch should be called', async () =>{ 
    const callFunction = getAgencyData.mockReturnValue(Promise.resolve(sampleAgencyData)); 
    const data = await getAgencyData(); 
    expect(callFunction).toHaveBeenCalled(); 
    expect(data).toHaveLength(2);
    expect(data[0]).toHaveProperty('partId', 0);
  }); 

  // it('Agency page should render all the content', async () => {
  //   render(<ApplicationSelection />)

  //   expect(screen.getByText('Login')).toBeInTheDocument()
  // });

});