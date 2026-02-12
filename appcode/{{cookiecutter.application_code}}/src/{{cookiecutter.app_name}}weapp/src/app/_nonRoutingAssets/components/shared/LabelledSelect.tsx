import React from 'react';
import { InputLabel, MenuItem, FormControl, Select, FormHelperText, Box, SelectChangeEvent, SxProps, Theme } from '@mui/material';

// Define the option structure
interface Option {
  label: string;
  value: string | number;
}

// Define the component props
interface LabelledSelectProps {
  id: string,
  label?: string;
  labelId?: string;
  // options?: Option[];
  value: string | undefined;
  onChange: (event: SelectChangeEvent) => void;
  name?: string;
  error?: boolean;
  helperText?: string;
  disabled?: boolean;
  children?: React.ReactNode;
  labelFontSize?: string;
  shrink?: boolean;
  showEmptyOption?: boolean; // Control the visibility of the blank option
  emptyOptionText?: string; // Text for the empty option
  useFormControl?: boolean; // Toggle FormControl usage
}

const LabelledSelect: React.FC<LabelledSelectProps> = ({
    id,
    label,
    labelId,
    // options = [],
    value,
    onChange,
    name,
    error = false,
    helperText = `${label} error`,
    disabled = false,
    children,
    labelFontSize = '1rem',
    shrink = false,
    showEmptyOption = false, // Show the empty option by default
    emptyOptionText = '-', // Customizable text for the empty option
    useFormControl = false, // New prop to toggle FormControl usage
}) => {
  return (
    <Box width="100%" mb={3} className='JAMLabelledSelect-root'>
      {label && <InputLabel id={labelId} sx={{ "{{" }} position: 'relative', display: 'inline', fontSize: labelFontSize, top: 0, left:0{{ "}}" }} className='JAMLabelledSelect-label'>{label}</InputLabel>}
      <FormControl className='JAMLabelledSelect-control' fullWidth variant="outlined" error={error} disabled={disabled}>
        <Select
          id={id}
          labelId={labelId}
          value={value}
          onChange={onChange}
          displayEmpty
          name={name}
          label={undefined} // Only set the label for accessibility if it's visible
          // label={label && shrink ? label : undefined} // Only set the label for accessibility if it's visible
        >
        {showEmptyOption && (
            <MenuItem value="">
              {emptyOptionText || 'None'} {/* Render empty option */}
            </MenuItem>
          )}
            {children}
          {/* {options.map((option) => (
            <MenuItem key={option.value} value={option.value}>
              {option.label}
            </MenuItem>
          ))} */}
        </Select>
        {error && helperText && <FormHelperText>{helperText}</FormHelperText>}
      </FormControl>
    </Box>
  );
};

export default LabelledSelect;