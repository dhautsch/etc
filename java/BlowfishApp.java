package com.hautsch;
// export as a runnable jar with are referenced jars included.

import com.siperian.common.security.Blowfish;

import javafx.application.Application;
import javafx.beans.value.ChangeListener;
import javafx.beans.value.ObservableValue;
import javafx.collections.FXCollections;
import javafx.event.*;
import javafx.geometry.*;
import javafx.scene.Scene;
import javafx.scene.control.*;
import javafx.scene.layout.*;
import javafx.scene.text.*;
import javafx.stage.Stage;

import javax.crypto.Cipher;
import javax.crypto.spec.SecretKeySpec;

public class DecryptString extends Application {
	final static String HEX_STRING = "0123456789ABCDEF";
	// following keys are bogus but their lengths are correct
	final static char[] SIPERIAN_KEY = {'{','1','0','1','0','A','A','A','A','-','1','1','1','1','-','1','1','1','1','-','1','1','1','1','-','1','1','1','1','1','1','1','1','1','1','1','1','}',0};
	final static char[] SHORT_KEY   =  (new String(SIPERIAN_KEY)).substring(0, 16).toCharArray();
	/**
	 * @param args
	 */
	public static void main(String[] args) {
		launch(args);
	}

	@Override
	public void start(Stage primaryStage) {
		primaryStage.setTitle("JavaFX Welcome - 20151023");
		GridPane grid = new GridPane();
		grid.setAlignment(Pos.CENTER);
		grid.setHgap(10);
		grid.setVgap(10);
		grid.setPadding(new Insets(25, 25, 25, 25));
		
        ColumnConstraints col1 = new ColumnConstraints();
        col1.setPercentWidth(25);
        ColumnConstraints col2 = new ColumnConstraints();
        col2.setPercentWidth(75);

        grid.getColumnConstraints().addAll(col1,col2);
        
		final Text scenetitle = new Text("Enter Encrypted String");
		scenetitle.setFont(Font.font("Tahoma", FontWeight.NORMAL, 20));
		grid.add(scenetitle, 0, 0, 2, 1);

		final String[] inputType = new String[] { "Encrypted", "Plain Text" };
		final String[] btnLabel = new String[] { "Decrypt", "Encrypt" };
		final ChoiceBox inputTypeCB = new ChoiceBox(
				FXCollections.observableArrayList(inputType));
		
		grid.add(inputTypeCB, 0, 1);

		inputTypeCB.getSelectionModel().select(0);

		final TextField inputTextField = new TextField();
		grid.add(inputTextField, 1, 1);

		Label outputLabel = new Label("Output:");
		grid.add(outputLabel, 0, 2);

		final TextField outputTextField = new TextField();
		grid.add(outputTextField, 1, 2);
		outputTextField.setEditable(false);

		final CheckBox siperian = new CheckBox("Use Siperian key");
		grid.add(siperian, 0, 3);
		siperian.setSelected(false);

		final Blowfish bfish_ = new Blowfish(new String(SIPERIAN_KEY));

		final Button btn = new Button(btnLabel[0]);

		inputTypeCB.getSelectionModel().selectedIndexProperty()
		.addListener(new ChangeListener<Number>() {
			public void changed(ObservableValue ov, Number value,
					Number newValue) {
				scenetitle.setText("Enter "
						+ inputType[newValue.intValue()] + " String");
				btn.setText(btnLabel[newValue.intValue()]);
			}
		});

		HBox hbBtn = new HBox(10);
		hbBtn.setAlignment(Pos.BOTTOM_RIGHT);
		hbBtn.getChildren().add(btn);
		grid.add(hbBtn, 1, 4);

		btn.setOnAction(new EventHandler<ActionEvent>() {

			@Override
			public void handle(ActionEvent e) {
				String input_ = inputTextField.getText();
				String output_ = null;

				if (inputTypeCB.getSelectionModel().getSelectedIndex() == 0) {
					if (siperian.isSelected())
						output_ = bfish_.decrypt(input_);
					else
						output_ = decrypt(input_);
				} else {
					if (siperian.isSelected())
						output_ = bfish_.encrypt(input_);
					else
						output_ = encrypt(input_);
				}
				outputTextField.setText(output_);
			}
		});

		Scene scene = new Scene(grid, 575, 275);
		primaryStage.setScene(scene);

		primaryStage.show();
	}

	public static String encrypt(String to_encrypt) {
		try {
			String key_ = new String(SHORT_KEY);
			SecretKeySpec key = new SecretKeySpec(key_.getBytes(), "Blowfish");
			Cipher cipher = Cipher.getInstance("Blowfish");
			cipher.init(Cipher.ENCRYPT_MODE, key);
			return new String(
					convertBinary2Hexadecimal(cipher.doFinal(to_encrypt
							.getBytes())));
		} catch (Exception e) {
			System.err.print(e);
			return null;
		}
	}

	public static String decrypt(String to_decrypt) {
		try {
			String key_ = new String(SHORT_KEY);
			SecretKeySpec key = new SecretKeySpec(key_.getBytes(), "Blowfish");
			Cipher cipher = Cipher.getInstance("Blowfish");
			cipher.init(Cipher.DECRYPT_MODE, key);
			byte[] decrypted = cipher
					.doFinal(convertHexadecimal2Binary(to_decrypt.getBytes()));
			return new String(decrypted);
		} catch (Exception e) {
			System.err.print(e);
			return null;
		}
	}

	private static String convertBinary2Hexadecimal(byte[] binary) {
		StringBuffer buf = new StringBuffer();
		int block = 0;

		for (int i = 0; i < binary.length; i++) {
			block = binary[i] & 0xFF;
			buf.append(HEX_STRING.charAt(block >> 4));
			buf.append(HEX_STRING.charAt(binary[i] & 0x0F));
		}

		return buf.toString();
	}

	public static byte[] convertHexadecimal2Binary(byte[] hex) {
		int block = 0;
		byte[] data = new byte[hex.length / 2];
		int index = 0;
		boolean next = false;

		for (int i = 0; i < hex.length; i++) {
			block <<= 4;
			int pos = HEX_STRING.indexOf(Character.toUpperCase((char) hex[i]));
			if (pos > -1)
				block += pos;

			if (next) {
				data[index] = (byte) (block & 0xff);
				index++;
				next = false;
			} else
				next = true;
		}

		return data;
	}

}
