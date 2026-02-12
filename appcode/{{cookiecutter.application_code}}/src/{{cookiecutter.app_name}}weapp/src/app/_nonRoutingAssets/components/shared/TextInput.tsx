import React from 'react';
import { Box, InputLabel, TextField, Typography, FormControl, FormHelperText, SxProps, Theme } from '@mui/material';

interface CustomTextInputProps {
  id: string,
  label?: string; // Label content
  value: string;
  onChange?: (event: React.ChangeEvent<HTMLInputElement>) => void;
  error?: boolean;
  helperText?: string;
  disabled?: boolean;
  labelFontSize?: string;
  placeholder?: string;
  type?: string; // Input type (text, password, etc.)
  shrink?: boolean; // Control label shrink behavior
  fullWidth?: boolean; // Control width
  useFormControl?: boolean; // Toggle FormControl usage
}

const CustomTextInput: React.FC<CustomTextInputProps> = ({
  id,
  label,
  value,
  onChange,
  error = false,
  helperText = `${label} error`,
  disabled = false,
  labelFontSize = '1rem',
  placeholder = '',
  type = 'text',
  shrink = false,
  fullWidth = false,
  useFormControl = true,
}) => {
  const labelId = `${id}-label`;
  const labelStyles: SxProps<Theme> = shrink
  ? { position: 'absolute', top: -10, left: 10, fontSize: '0.875rem', background: 'white', padding: 0, borderRadius: 1 }
    : { position: 'relative', display: 'inline', fontSize: labelFontSize, top: 0, left:0};
  // Only apply FormControl for structured form management when needed
  const inputComponent = (
    <>
      {shrink || !label ? (
        <TextField
          id={id}
          value={value}
          onChange={onChange}
          error={error}
          disabled={disabled}
          placeholder={placeholder}
          type={type}
          variant="outlined"
          fullWidth={fullWidth}
          label={shrink ? label : undefined} // Only show label in TextField if shrink is true
          InputLabelProps={{ "{{" }} // Control the shrink behavior
            shrink: shrink,
            htmlFor: id,
            id: labelId,
          {{ "}}" }}
        />
      ) : (
        <>
          {!useFormControl && label && <InputLabel id={id} sx={labelStyles}>{label}</InputLabel>}
          <TextField
            id={id}
            label={undefined}
            value={value}
            onChange={onChange}
            error={error}
            disabled={disabled}
            placeholder={placeholder}
            type={type}
            variant="outlined"
            fullWidth={fullWidth}
            InputLabelProps={{ "{{" }} // Control the shrink behavior
              htmlFor: id,
              id: labelId,
            {{ "}}" }}
          />
        </>
      )}
      {error && helperText && <FormHelperText error={error}>{helperText}</FormHelperText>}
    </>
  );

  return (
    <Box width="100%" className='JAMTextInput-root'>
      {useFormControl ? (
        <>
          { label && <InputLabel id={labelId} className='JAMTextInput-label' sx={labelStyles}>{label}</InputLabel>}
          <FormControl className='JAMTextInput-control' fullWidth error={error} disabled={disabled} variant="outlined" sx={{ "{{" }}marginTop: label ? 1 : 0{{ "}}" }}>
            {inputComponent}
          </FormControl>
        </>
      ) : inputComponent}
    </Box>
  );
};

export default CustomTextInput;